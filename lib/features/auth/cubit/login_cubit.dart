import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/connection_form_inputs.dart';
import '../data/models/connection_config.dart';
import '../data/repositories/connection_repository.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({
    required ConnectionRepository connectionRepository,
    SecureStorageService? secureStorage,
    String defaultIp = '192.168.1.20',
    String defaultPort = '8443',
    String defaultUsername = 'fiscal',
    Duration approvalPollInterval = const Duration(seconds: 3),
    Duration transientRetryInterval = const Duration(seconds: 8),
  }) : _connectionRepository = connectionRepository,
       _secureStorage = secureStorage ?? SecureStorageService(),
       _approvalPollInterval = approvalPollInterval,
       _transientRetryInterval = transientRetryInterval,
       super(
         LoginState(
           ip: IpAddressInput.pure(defaultIp),
           port: PortInput.pure(defaultPort),
           username: UsernameInput.pure(defaultUsername),
         ),
       );

  final ConnectionRepository _connectionRepository;
  final SecureStorageService _secureStorage;
  final Duration _approvalPollInterval;
  final Duration _transientRetryInterval;
  int _pollingGeneration = 0;

  /// Pré-preenche IP/porta/usuário da última conexão lembrada (não a senha).
  Future<void> loadLastConnection() async {
    ({String ip, String port, String username})? last;
    try {
      last = await _secureStorage.readLastConnection();
    } catch (_) {
      // O formulário continua utilizável se o Keychain/Keystore estiver
      // temporariamente indisponível (incluindo testes sem plugins nativos).
      return;
    }
    if (isClosed) return;
    if (last == null) {
      return;
    }
    // Remove os dados de demonstração gravados por versões antigas do app.
    // Sem esta migração, uma atualização mantém 192.168.1.1:8080/guarda no
    // armazenamento seguro e acaba sobrescrevendo a configuração real.
    if (last.ip == '192.168.1.1' &&
        last.port == '8080' &&
        last.username == 'guarda') {
      await _secureStorage.clear();
      return;
    }
    // Corrige a porta HTTP gravada pela versão anterior: o listener móvel
    // confirmado pelo FaceTrack opera via HTTPS/WSS em 8443.
    if (last.port == '8000') {
      last = (ip: last.ip, port: '8443', username: last.username);
    }
    emit(
      state.copyWith(
        ip: IpAddressInput.dirty(last.ip),
        port: PortInput.dirty(last.port),
        username: UsernameInput.dirty(last.username),
      ),
    );
  }

  void ipChanged(String value) =>
      emit(state.copyWith(ip: IpAddressInput.dirty(value)));

  void portChanged(String value) =>
      emit(state.copyWith(port: PortInput.dirty(value)));

  void usernameChanged(String value) =>
      emit(state.copyWith(username: UsernameInput.dirty(value)));

  void operatorNameChanged(String value) =>
      emit(state.copyWith(operatorName: OperatorNameInput.dirty(value)));

  void passwordChanged(String value) =>
      emit(state.copyWith(password: PasswordInput.dirty(value)));

  void rememberConnectionChanged(bool value) =>
      emit(state.copyWith(rememberConnection: value));

  Future<void> submit() async {
    if (!state.isValid || state.isLoading || state.awaitingApproval) return;
    _pollingGeneration++;
    emit(
      state.copyWith(
        status: FormzSubmissionStatus.inProgress,
        awaitingApproval: false,
        clearApprovalExpiresAt: true,
      ),
    );
    try {
      final attempt = await _connectionRepository.connect(
        ip: state.ip.value,
        port: state.port.value,
        operatorName: '',
        username: state.username.value,
        password: state.password.value,
      );

      if (state.rememberConnection) {
        await _secureStorage.saveLastConnection(
          ip: state.ip.value,
          port: state.port.value,
          username: state.username.value,
        );
      } else {
        await _secureStorage.clear();
      }

      if (isClosed) return;
      await _handleAttempt(attempt);
    } on ConnectionException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: 'Não foi possível conectar ao software principal.',
        ),
      );
    }
  }

  Future<void> _handleAttempt(ConnectionAttempt attempt) async {
    switch (attempt) {
      case ConnectionAuthorized(:final connection):
        emit(
          state.copyWith(
            status: FormzSubmissionStatus.success,
            connection: connection,
            awaitingApproval: false,
            clearApprovalExpiresAt: true,
          ),
        );
      case ConnectionPendingApproval(:final expiresAt):
        final generation = ++_pollingGeneration;
        emit(
          state.copyWith(
            status: FormzSubmissionStatus.initial,
            awaitingApproval: true,
            approvalExpiresAt: expiresAt,
            clearConnection: true,
          ),
        );
        unawaited(_pollApproval(generation));
    }
  }

  Future<void> _pollApproval(int generation) async {
    var delay = _approvalPollInterval;
    while (!isClosed &&
        generation == _pollingGeneration &&
        state.awaitingApproval) {
      await Future<void>.delayed(delay);
      if (isClosed ||
          generation != _pollingGeneration ||
          !state.awaitingApproval) {
        return;
      }
      try {
        final attempt = await _connectionRepository.pollApproval();
        if (isClosed || generation != _pollingGeneration) return;
        if (attempt is ConnectionAuthorized) {
          await _handleAttempt(attempt);
          return;
        }
        delay = _approvalPollInterval;
      } on ConnectionException catch (error) {
        if (isClosed || generation != _pollingGeneration) return;
        if (error.isTransient) {
          delay = _transientRetryInterval;
          continue;
        }
        emit(
          state.copyWith(
            status: FormzSubmissionStatus.failure,
            errorMessage: error.message,
            awaitingApproval: false,
            clearApprovalExpiresAt: true,
          ),
        );
        return;
      }
    }
  }

  void cancelApproval() {
    _pollingGeneration++;
    emit(
      state.copyWith(
        status: FormzSubmissionStatus.initial,
        awaitingApproval: false,
        clearApprovalExpiresAt: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _pollingGeneration++;
    return super.close();
  }
}
