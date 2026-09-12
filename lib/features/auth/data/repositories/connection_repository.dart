import '../models/connection_config.dart';

/// Erro de autenticação/conexão com o software principal (IP/porta errados,
/// credenciais inválidas, ou o computador da loja não respondeu).
class ConnectionException implements Exception {
  const ConnectionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Seam entre o app e o software principal. A implementação real (fase 2)
/// troca o mock por chamadas HTTP/WebSocket para `http://ip:porta`, sem
/// mudar nada em LoginCubit/DetectionsCubit — eles só conhecem esta interface.
abstract class ConnectionRepository {
  /// Abre a sessão: valida IP/porta alcançáveis e usuário/senha junto ao
  /// software principal. Lança [ConnectionException] em caso de falha.
  Future<ConnectionConfig> connect({
    required String ip,
    required String port,
    required String username,
    required String password,
  });

  /// Encerra a sessão local do app — não afeta contas nem dados no software
  /// principal, já que o app é somente leitura.
  Future<void> disconnect();
}
