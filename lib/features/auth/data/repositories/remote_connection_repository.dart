import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_response.dart';
import '../../../../core/network/api_session.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/connection_config.dart';
import 'connection_repository.dart';

class RemoteConnectionRepository implements ConnectionRepository {
  RemoteConnectionRepository({
    required ApiSession session,
    SecureStorageService? secureStorage,
    this.scheme = 'https',
  }) : _session = session,
       _secureStorage = secureStorage ?? SecureStorageService();

  final ApiSession _session;
  final SecureStorageService _secureStorage;
  final String scheme;

  _PendingPairing? _pendingPairing;

  static const _requestTimeout = Duration(seconds: 8);

  @override
  Future<ConnectionAttempt> connect({
    required String ip,
    required String port,
    required String operatorName,
    required String username,
    required String password,
  }) async {
    if (scheme != 'https' && scheme != 'http') {
      throw const ConnectionException('Esquema de conexão inválido.');
    }

    final host = ip.trim();
    final normalizedUsername = username.trim();
    final baseUri = Uri(scheme: scheme, host: host, port: int.parse(port));
    final deviceId = await _secureStorage.readOrCreateDeviceId();
    final shortDeviceId = deviceId.substring(0, 8);

    try {
      final response = await _session.client
          .post(
            baseUri.replace(path: '/api/mobile/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'device_id': deviceId,
              'device_name': 'FaceTrack Mobile $shortDeviceId',
              'username': normalizedUsername,
              'password': password,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 202) {
        final body = decodeJsonObject(response);
        final status = _requiredString(body, 'status');
        if (status == 'authorized') {
          final token = _requiredString(body, 'token');
          _pendingPairing = null;
          return ConnectionAuthorized(
            await _authorize(
              baseUri: baseUri,
              host: host,
              port: port,
              username: normalizedUsername,
              token: token,
            ),
          );
        }
        if (status != 'pending_approval') {
          throw FormatException('Status de login inesperado: $status.');
        }
        final pairingSecret = _requiredString(body, 'pairing_secret');
        final expiresIn = body['expires_in_seconds'];
        if (expiresIn is! int || expiresIn <= 0) {
          throw const FormatException('Validade do pareamento inválida.');
        }
        final pending = _PendingPairing(
          baseUri: baseUri,
          host: host,
          port: port,
          username: normalizedUsername,
          deviceId: deviceId,
          pairingSecret: pairingSecret,
          expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        );
        _pendingPairing = pending;
        return ConnectionPendingApproval(
          deviceId: deviceId,
          expiresAt: pending.expiresAt,
        );
      }

      throw ConnectionException(_loginErrorMessage(response));
    } on ConnectionException {
      rethrow;
    } on http.ClientException {
      throw const ConnectionException(
        'Não foi possível alcançar o FaceTrack. Verifique o Wi-Fi, IP e porta.',
        isTransient: true,
      );
    } on FormatException catch (error) {
      throw ConnectionException(
        'Resposta inválida do FaceTrack: ${error.message}',
      );
    } catch (_) {
      throw const ConnectionException(
        'A conexão expirou ou o FaceTrack não respondeu.',
        isTransient: true,
      );
    }
  }

  @override
  Future<ConnectionAttempt> pollApproval() async {
    final pending = _pendingPairing;
    if (pending == null) {
      throw const ConnectionException(
        'Não existe uma solicitação de pareamento ativa.',
      );
    }
    if (DateTime.now().isAfter(pending.expiresAt)) {
      _pendingPairing = null;
      throw const ConnectionException(
        'A autorização expirou. Faça o login novamente.',
      );
    }

    try {
      final response = await _session.client
          .get(
            pending.baseUri.replace(
              path: '/api/mobile/status',
              queryParameters: {'device_id': pending.deviceId},
            ),
            headers: {
              'Accept': 'application/json',
              'X-Pairing-Secret': pending.pairingSecret,
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 503) {
        throw const ConnectionException(
          'O módulo mobile está temporariamente indisponível.',
          isTransient: true,
        );
      }
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        _pendingPairing = null;
        throw ConnectionException(
          apiErrorMessage(
            response,
            response.statusCode == 401
                ? 'A autorização expirou. Faça o login novamente.'
                : 'A solicitação de autorização foi recusada.',
          ),
        );
      }
      if (response.statusCode != 200) {
        throw ConnectionException(
          apiErrorMessage(
            response,
            'Falha ao consultar a autorização (${response.statusCode}).',
          ),
          isTransient: response.statusCode >= 500,
        );
      }

      final body = decodeJsonObject(response);
      final status = _requiredString(body, 'status');
      if (status == 'pending') {
        return ConnectionPendingApproval(
          deviceId: pending.deviceId,
          expiresAt: pending.expiresAt,
        );
      }
      if (status == 'rejected') {
        _pendingPairing = null;
        throw const ConnectionException(
          'A solicitação foi recusada pelo gerente.',
        );
      }
      if (status != 'authorized') {
        throw FormatException('Status de autorização desconhecido: $status.');
      }

      final token = _requiredString(body, 'token');
      _pendingPairing = null;
      return ConnectionAuthorized(
        await _authorize(
          baseUri: pending.baseUri,
          host: pending.host,
          port: pending.port,
          username: pending.username,
          token: token,
        ),
      );
    } on ConnectionException {
      rethrow;
    } on http.ClientException {
      throw const ConnectionException(
        'A rede local está indisponível. Aguardando para tentar novamente.',
        isTransient: true,
      );
    } on FormatException catch (error) {
      throw ConnectionException(
        'Resposta inválida do FaceTrack: ${error.message}',
      );
    } catch (_) {
      throw const ConnectionException(
        'O FaceTrack não respondeu. Aguardando para tentar novamente.',
        isTransient: true,
      );
    }
  }

  @override
  Future<ConnectionConfig?> restoreSession() async {
    final saved = await _secureStorage.readAuthenticatedSession();
    if (saved == null) return null;
    if (saved.scheme != scheme) {
      await _secureStorage.clearAuthenticatedSession();
      return null;
    }
    final baseUri = Uri(
      scheme: saved.scheme,
      host: saved.host,
      port: int.parse(saved.port),
    );
    _session.establish(baseUri: baseUri, accessToken: saved.token);
    return ConnectionConfig(
      ip: saved.host,
      port: saved.port,
      username: saved.username,
      scheme: saved.scheme,
    );
  }

  Future<ConnectionConfig> _authorize({
    required Uri baseUri,
    required String host,
    required String port,
    required String username,
    required String token,
  }) async {
    _session.establish(baseUri: baseUri, accessToken: token);
    await _secureStorage.saveAuthenticatedSession(
      scheme: baseUri.scheme,
      host: host,
      port: port,
      username: username,
      token: token,
    );
    return ConnectionConfig(
      ip: host,
      port: port,
      username: username,
      scheme: baseUri.scheme,
    );
  }

  String _loginErrorMessage(http.Response response) {
    final fallback = switch (response.statusCode) {
      401 => 'Usuário ou senha de fiscal incorretos.',
      403 => 'Este aparelho foi recusado pelo gerente.',
      503 => 'O módulo de fiscais móveis está desativado.',
      _ => 'O FaceTrack recusou a conexão (${response.statusCode}).',
    };
    return apiErrorMessage(response, fallback);
  }

  @override
  Future<void> disconnect() async {
    _pendingPairing = null;
    if (_session.isAuthenticated) {
      try {
        await _session.client
            .post(
              _session.endpoint('/api/mobile/logout'),
              headers: _session.authorizationHeaders,
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // O logout local não pode manter a interface autenticada. Uma nova
        // autenticação rotaciona e invalida o token anterior no servidor.
      }
    }
    _session.clear();
    await _secureStorage.clearAuthenticatedSession();
  }
}

final class _PendingPairing {
  const _PendingPairing({
    required this.baseUri,
    required this.host,
    required this.port,
    required this.username,
    required this.deviceId,
    required this.pairingSecret,
    required this.expiresAt,
  });

  final Uri baseUri;
  final String host;
  final String port;
  final String username;
  final String deviceId;
  final String pairingSecret;
  final DateTime expiresAt;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key ausente ou inválido.');
}
