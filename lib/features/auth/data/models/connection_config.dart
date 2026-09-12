import 'package:equatable/equatable.dart';

/// Dados de conexão com o software principal na rede local da loja.
final class ConnectionConfig extends Equatable {
  const ConnectionConfig({
    required this.ip,
    required this.port,
    required this.username,
  });

  final String ip;
  final String port;
  final String username;

  String get address => '$ip:$port';

  @override
  List<Object?> get props => [ip, port, username];
}
