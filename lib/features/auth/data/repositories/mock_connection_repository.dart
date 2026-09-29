import '../models/connection_config.dart';
import 'connection_repository.dart';

/// Implementação mockada: simula a latência de rede local e valida contra
/// uma credencial fixa de demonstração, já que o software principal ainda
/// não expõe uma API real para autenticar o app.
///
/// Credencial de demo: usuário `guarda`, senha `1234`.
class MockConnectionRepository implements ConnectionRepository {
  static const _demoUsername = 'guarda';
  static const _demoPassword = '1234';

  @override
  Future<ConnectionAttempt> connect({
    required String ip,
    required String port,
    required String operatorName,
    required String username,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (username.trim().toLowerCase() != _demoUsername ||
        password != _demoPassword) {
      throw const ConnectionException(
        'Usuário ou senha inválidos. Verifique com o administrador do sistema.',
      );
    }

    return ConnectionAuthorized(
      ConnectionConfig(
        ip: ip,
        port: port,
        username: username.trim(),
        scheme: 'http',
      ),
    );
  }

  @override
  Future<ConnectionAttempt> pollApproval() => throw const ConnectionException(
    'O modo de demonstração não possui aprovação pendente.',
  );

  @override
  Future<ConnectionConfig?> restoreSession() async => null;

  @override
  Future<void> disconnect() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}
