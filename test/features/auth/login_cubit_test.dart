import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:formz/formz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela_app/core/storage/secure_storage_service.dart';
import 'package:sentinela_app/core/utils/connection_form_inputs.dart';
import 'package:sentinela_app/features/auth/cubit/login_cubit.dart';
import 'package:sentinela_app/features/auth/data/models/connection_config.dart';
import 'package:sentinela_app/features/auth/data/repositories/connection_repository.dart';

class _MockConnectionRepository extends Mock implements ConnectionRepository {}

/// A senha nunca é persistida — o fake só garante que os métodos de
/// storage não toquem o plugin nativo (indisponível em testes unitários).
class _FakeSecureStorageService extends SecureStorageService {
  ({String ip, String port, String username})? lastConnection;
  String? operatorName;
  bool wasCleared = false;

  @override
  Future<void> saveLastConnection({
    required String ip,
    required String port,
    required String username,
  }) async {}

  @override
  Future<({String ip, String port, String username})?>
  readLastConnection() async => lastConnection;

  @override
  Future<void> clear() async {
    wasCleared = true;
    lastConnection = null;
  }

  @override
  Future<String?> readOperatorName() async => operatorName;

  @override
  Future<void> saveOperatorName(String value) async {
    operatorName = value;
  }
}

void main() {
  late _MockConnectionRepository connectionRepository;
  late _FakeSecureStorageService secureStorage;

  const validSeed = LoginState(
    ip: IpAddressInput.dirty('192.168.0.10'),
    port: PortInput.dirty('8080'),
    username: UsernameInput.dirty('guarda'),
    password: PasswordInput.dirty('1234'),
  );

  setUp(() {
    connectionRepository = _MockConnectionRepository();
    secureStorage = _FakeSecureStorageService();
  });

  group('LoginCubit', () {
    test(
      'remove a configuração de demonstração salva por versões antigas',
      () async {
        secureStorage.lastConnection = (
          ip: '192.168.1.1',
          port: '8080',
          username: 'guarda',
        );
        final cubit = LoginCubit(
          connectionRepository: connectionRepository,
          secureStorage: secureStorage,
        );

        await cubit.loadLastConnection();

        expect(cubit.state.ip.value, '192.168.1.20');
        expect(cubit.state.port.value, '8443');
        expect(cubit.state.username.value, 'fiscal');
        expect(secureStorage.wasCleared, isTrue);
        await cubit.close();
      },
    );

    blocTest<LoginCubit, LoginState>(
      'emite [inProgress, success] quando a conexão é válida',
      setUp: () =>
          when(
            () => connectionRepository.connect(
              ip: any(named: 'ip'),
              port: any(named: 'port'),
              operatorName: any(named: 'operatorName'),
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          ).thenAnswer(
            (_) async => const ConnectionAuthorized(
              ConnectionConfig(
                ip: '192.168.0.10',
                port: '8080',
                username: 'guarda',
              ),
            ),
          ),
      build: () => LoginCubit(
        connectionRepository: connectionRepository,
        secureStorage: secureStorage,
      ),
      seed: () => validSeed,
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          FormzSubmissionStatus.inProgress,
        ),
        isA<LoginState>()
            .having((s) => s.status, 'status', FormzSubmissionStatus.success)
            .having((s) => s.connection, 'connection', isNotNull),
      ],
      verify: (_) => verify(
        () => connectionRepository.connect(
          ip: '192.168.0.10',
          port: '8080',
          operatorName: '',
          username: 'guarda',
          password: '1234',
        ),
      ).called(1),
    );

    blocTest<LoginCubit, LoginState>(
      'emite [inProgress, failure] com a mensagem quando a conexão falha',
      setUp: () => when(
        () => connectionRepository.connect(
          ip: any(named: 'ip'),
          port: any(named: 'port'),
          operatorName: any(named: 'operatorName'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const ConnectionException('Usuário ou senha inválidos.')),
      build: () => LoginCubit(
        connectionRepository: connectionRepository,
        secureStorage: secureStorage,
      ),
      seed: () => validSeed,
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<LoginState>().having(
          (s) => s.status,
          'status',
          FormzSubmissionStatus.inProgress,
        ),
        isA<LoginState>()
            .having((s) => s.status, 'status', FormzSubmissionStatus.failure)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Usuário ou senha inválidos.',
            ),
      ],
    );

    blocTest<LoginCubit, LoginState>(
      'aguarda o gerente e conclui após o polling autorizar',
      setUp: () {
        when(
          () => connectionRepository.connect(
            ip: any(named: 'ip'),
            port: any(named: 'port'),
            operatorName: any(named: 'operatorName'),
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => ConnectionPendingApproval(
            deviceId: 'device-1',
            expiresAt: DateTime.now().add(const Duration(minutes: 15)),
          ),
        );
        when(() => connectionRepository.pollApproval()).thenAnswer(
          (_) async => const ConnectionAuthorized(
            ConnectionConfig(
              ip: '192.168.0.10',
              port: '8080',
              username: 'guarda',
            ),
          ),
        );
      },
      build: () => LoginCubit(
        connectionRepository: connectionRepository,
        secureStorage: secureStorage,
        approvalPollInterval: const Duration(milliseconds: 1),
      ),
      seed: () => validSeed,
      act: (cubit) => cubit.submit(),
      wait: const Duration(milliseconds: 20),
      expect: () => [
        isA<LoginState>().having(
          (state) => state.status,
          'status',
          FormzSubmissionStatus.inProgress,
        ),
        isA<LoginState>().having(
          (state) => state.awaitingApproval,
          'awaitingApproval',
          isTrue,
        ),
        isA<LoginState>()
            .having(
              (state) => state.status,
              'status',
              FormzSubmissionStatus.success,
            )
            .having(
              (state) => state.awaitingApproval,
              'awaitingApproval',
              isFalse,
            ),
      ],
      verify: (_) =>
          verify(() => connectionRepository.pollApproval()).called(1),
    );

    blocTest<LoginCubit, LoginState>(
      'não envia quando o formulário é inválido',
      build: () => LoginCubit(
        connectionRepository: connectionRepository,
        secureStorage: secureStorage,
      ),
      act: (cubit) => cubit.submit(),
      expect: () => <LoginState>[],
      verify: (_) => verifyNever(
        () => connectionRepository.connect(
          ip: any(named: 'ip'),
          port: any(named: 'port'),
          operatorName: any(named: 'operatorName'),
          username: any(named: 'username'),
          password: any(named: 'password'),
        ),
      ),
    );
  });
}
