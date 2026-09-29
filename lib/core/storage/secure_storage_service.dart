import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda localmente apenas o endereço de conexão (IP/porta/usuário) para
/// facilitar reconectar ao mesmo software principal — NUNCA a senha.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _ipKey = 'last_ip_address';
  static const _portKey = 'last_port';
  static const _usernameKey = 'last_username';
  static const _operatorNameKey = 'last_operator_name';
  static const _deviceIdKey = 'facetrack_device_id';
  static const _sessionSchemeKey = 'facetrack_session_scheme';
  static const _sessionHostKey = 'facetrack_session_host';
  static const _sessionPortKey = 'facetrack_session_port';
  static const _sessionUsernameKey = 'facetrack_session_username';
  static const _sessionTokenKey = 'facetrack_session_token';
  static const _alertToneKey = 'facetrack_alert_tone';
  static const _alertVolumeKey = 'facetrack_alert_volume';

  Future<void> saveLastConnection({
    required String ip,
    required String port,
    required String username,
  }) async {
    await _storage.write(key: _ipKey, value: ip);
    await _storage.write(key: _portKey, value: port);
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<({String ip, String port, String username})?>
  readLastConnection() async {
    final ip = await _storage.read(key: _ipKey);
    final port = await _storage.read(key: _portKey);
    final username = await _storage.read(key: _usernameKey);
    if (ip == null || port == null || username == null) return null;
    return (ip: ip, port: port, username: username);
  }

  Future<void> clear() async {
    await _storage.delete(key: _ipKey);
    await _storage.delete(key: _portKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _operatorNameKey);
  }

  Future<void> saveOperatorName(String operatorName) =>
      _storage.write(key: _operatorNameKey, value: operatorName.trim());

  Future<String?> readOperatorName() => _storage.read(key: _operatorNameKey);

  /// UUID v4 aleatório que identifica somente esta instalação. Não utiliza
  /// IMEI, serial, MAC address nem qualquer identificador de hardware.
  Future<String> readOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateUuidV4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<void> saveAuthenticatedSession({
    required String scheme,
    required String host,
    required String port,
    required String username,
    required String token,
  }) async {
    await _storage.write(key: _sessionSchemeKey, value: scheme);
    await _storage.write(key: _sessionHostKey, value: host);
    await _storage.write(key: _sessionPortKey, value: port);
    await _storage.write(key: _sessionUsernameKey, value: username);
    await _storage.write(key: _sessionTokenKey, value: token);
  }

  Future<
    ({String scheme, String host, String port, String username, String token})?
  >
  readAuthenticatedSession() async {
    final scheme = await _storage.read(key: _sessionSchemeKey);
    final host = await _storage.read(key: _sessionHostKey);
    final port = await _storage.read(key: _sessionPortKey);
    final username = await _storage.read(key: _sessionUsernameKey);
    final token = await _storage.read(key: _sessionTokenKey);
    if (scheme == null ||
        host == null ||
        port == null ||
        username == null ||
        token == null) {
      return null;
    }
    return (
      scheme: scheme,
      host: host,
      port: port,
      username: username,
      token: token,
    );
  }

  Future<void> clearAuthenticatedSession() async {
    await _storage.delete(key: _sessionSchemeKey);
    await _storage.delete(key: _sessionHostKey);
    await _storage.delete(key: _sessionPortKey);
    await _storage.delete(key: _sessionUsernameKey);
    await _storage.delete(key: _sessionTokenKey);
  }

  Future<String?> readAlertTone() => _storage.read(key: _alertToneKey);

  Future<void> saveAlertTone(String tone) =>
      _storage.write(key: _alertToneKey, value: tone);

  Future<String?> readAlertVolume() => _storage.read(key: _alertVolumeKey);

  Future<void> saveAlertVolume(double volume) => _storage.write(
    key: _alertVolumeKey,
    value: volume.clamp(0.0, 1.0).toString(),
  );
}

String _generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
