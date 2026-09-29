import '../models/connection_config.dart';

/// Erro de autenticação/conexão com o software principal (IP/porta errados,
/// credenciais inválidas, ou o computador da loja não respondeu).
class ConnectionException implements Exception {
  const ConnectionException(this.message, {this.isTransient = false});
  final String message;
  final bool isTransient;

  @override
  String toString() => message;
}

sealed class ConnectionAttempt {
  const ConnectionAttempt();
}

final class ConnectionAuthorized extends ConnectionAttempt {
  const ConnectionAuthorized(this.connection);
  final ConnectionConfig connection;
}

final class ConnectionPendingApproval extends ConnectionAttempt {
  const ConnectionPendingApproval({
    required this.deviceId,
    required this.expiresAt,
  });

  final String deviceId;
  final DateTime expiresAt;
}

/// Seam entre o app e o software principal. A implementação real (fase 2)
/// troca o mock por chamadas HTTP/WebSocket para `http://ip:porta`, sem
/// mudar nada em LoginCubit/DetectionsCubit — eles só conhecem esta interface.
abstract class ConnectionRepository {
  /// Abre a sessão: valida IP/porta alcançáveis e usuário/senha junto ao
  /// software principal. Lança [ConnectionException] em caso de falha.
  Future<ConnectionAttempt> connect({
    required String ip,
    required String port,
    required String operatorName,
    required String username,
    required String password,
  });

  /// Consulta uma solicitação de pareamento já iniciada. A implementação
  /// mantém o pairing_secret somente em memória e nunca o persiste.
  Future<ConnectionAttempt> pollApproval();

  /// Restaura o token persistido de um aparelho já autorizado.
  Future<ConnectionConfig?> restoreSession();

  /// Encerra a sessão local do app — não afeta contas nem dados no software
  /// principal, já que o app é somente leitura.
  Future<void> disconnect();
}
