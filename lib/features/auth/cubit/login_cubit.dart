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
  })  : _connectionRepository = connectionRepository,
        _secureStorage = secureStorage ?? SecureStorageService(),
        super(const LoginState());

  final ConnectionRepository _connectionRepository;
  final SecureStorageService _secureStorage;

  /// Pré-preenche IP/porta/usuário da última conexão lembrada (não a senha).
  Future<void> loadLastConnection() async {
    final last = await _secureStorage.readLastConnection();
    if (last == null || isClosed) return;
    emit(state.copyWith(
      ip: IpAddressInput.dirty(last.ip),
      port: PortInput.dirty(last.port),
      username: UsernameInput.dirty(last.username),
    ));
  }

  void ipChanged(String value) =>
      emit(state.copyWith(ip: IpAddressInput.dirty(value)));

  void portChanged(String value) =>
      emit(state.copyWith(port: PortInput.dirty(value)));

  void usernameChanged(String value) =>
      emit(state.copyWith(username: UsernameInput.dirty(value)));

  void passwordChanged(String value) =>
      emit(state.copyWith(password: PasswordInput.dirty(value)));

  void rememberConnectionChanged(bool value) =>
      emit(state.copyWith(rememberConnection: value));

  Future<void> submit() async {
    if (!state.isValid || state.isLoading) return;
    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));
    try {
      final connection = await _connectionRepository.connect(
        ip: state.ip.value,
        port: state.port.value,
        username: state.username.value,
        password: state.password.value,
      );

      if (state.rememberConnection) {
        await _secureStorage.saveLastConnection(
          ip: connection.ip,
          port: connection.port,
          username: connection.username,
        );
      } else {
        await _secureStorage.clear();
      }

      if (isClosed) return;
      emit(state.copyWith(
        status: FormzSubmissionStatus.success,
        connection: connection,
      ));
    } on ConnectionException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: e.message,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Não foi possível conectar ao software principal.',
      ));
    }
  }
}
