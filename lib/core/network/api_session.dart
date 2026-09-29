import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Estado compartilhado da conexão autenticada com o software principal.
/// Durante a execução, esta é a fonte de verdade da sessão. O token persistido
/// pelo fluxo de pareamento é restaurado do armazenamento seguro no startup.
class ApiSession {
  ApiSession({http.Client? client, this.webSocketClient})
    : client = client ?? http.Client();

  /// Cliente do FaceTrack instalado na rede local da loja.
  ///
  /// O listener 8443 utiliza um certificado privado gerado pela instalação
  /// atual. Como o backend deixou de distribuir uma CA para o aplicativo, a
  /// exceção de confiança fica estritamente limitada ao certificado do
  /// FaceTrack, na porta 8443 e em endereços privados/.local. O mesmo transporte
  /// é compartilhado por REST e WSS.
  factory ApiSession.forLocalFaceTrack() {
    final transport = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback = _acceptLocalFaceTrackCertificate;
    return ApiSession(client: IOClient(transport), webSocketClient: transport);
  }

  final http.Client client;
  final HttpClient? webSocketClient;

  Uri? _baseUri;
  String? _accessToken;
  DateTime? _expiresAt;

  bool get isAuthenticated => _baseUri != null && _accessToken != null;
  Uri get baseUri => _baseUri ?? (throw StateError('Sessão não iniciada.'));
  String get accessToken =>
      _accessToken ?? (throw StateError('Sessão não iniciada.'));
  DateTime? get expiresAt => _expiresAt;

  Map<String, String> get authorizationHeaders => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
  };

  void establish({
    required Uri baseUri,
    required String accessToken,
    DateTime? expiresAt,
  }) {
    _baseUri = baseUri;
    _accessToken = accessToken;
    _expiresAt = expiresAt;
  }

  Uri endpoint(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(
      path: normalizedPath,
      queryParameters: queryParameters,
    );
  }

  Uri resolveServerUrl(String value) {
    final parsed = Uri.parse(value);
    final resolved = parsed.hasScheme ? parsed : baseUri.resolve(value);
    if (resolved.scheme != baseUri.scheme ||
        resolved.host != baseUri.host ||
        resolved.port != baseUri.port) {
      throw const FormatException('URL aponta para um servidor diferente.');
    }
    return resolved;
  }

  void clear() {
    _baseUri = null;
    _accessToken = null;
    _expiresAt = null;
  }

  void dispose() {
    clear();
    client.close();
  }
}

bool _acceptLocalFaceTrackCertificate(
  X509Certificate certificate,
  String host,
  int port,
) {
  if (port != 8443 || !_isPrivateStoreHost(host)) return false;

  final now = DateTime.now();
  if (now.isBefore(certificate.startValidity) ||
      now.isAfter(certificate.endValidity)) {
    return false;
  }

  return certificate.subject.contains('CN=FaceTrack Mobile Server') &&
      certificate.issuer.contains('CN=FaceTrack Mobile Store CA');
}

bool _isPrivateStoreHost(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.endsWith('.local')) return true;
  final parts = normalized.split('.');
  if (parts.length != 4) return false;
  final octets = parts.map(int.tryParse).toList(growable: false);
  if (octets.any((value) => value == null || value < 0 || value > 255)) {
    return false;
  }
  final values = octets.cast<int>();
  return values[0] == 10 ||
      (values[0] == 172 && values[1] >= 16 && values[1] <= 31) ||
      (values[0] == 192 && values[1] == 168);
}
