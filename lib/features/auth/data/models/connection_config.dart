import 'package:equatable/equatable.dart';

/// Dados de conexão com o software principal na rede local da loja.
final class ConnectionConfig extends Equatable {
  const ConnectionConfig({
    required this.ip,
    required this.port,
    required this.username,
    this.scheme = 'https',
  });

  final String ip;
  final String port;
  final String username;
  final String scheme;

  String get address => '$ip:$port';
  Uri get baseUri => Uri(scheme: scheme, host: ip, port: int.parse(port));

  @override
  List<Object?> get props => [ip, port, username, scheme];
}
