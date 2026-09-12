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

  Future<void> saveLastConnection({
    required String ip,
    required String port,
    required String username,
  }) async {
    await _storage.write(key: _ipKey, value: ip);
    await _storage.write(key: _portKey, value: port);
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<({String ip, String port, String username})?> readLastConnection() async {
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
  }
}
