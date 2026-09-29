import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentinela_app/core/network/api_session.dart';
import 'package:sentinela_app/core/storage/secure_storage_service.dart';
import 'package:sentinela_app/features/auth/data/repositories/connection_repository.dart';
import 'package:sentinela_app/features/auth/data/repositories/remote_connection_repository.dart';

class _FakeSecureStorageService extends SecureStorageService {
  String? savedToken;

  @override
  Future<String> readOrCreateDeviceId() async =>
      'c3a7e4b2-8f91-4d32-bb15-998877665544';

  @override
  Future<void> saveAuthenticatedSession({
    required String scheme,
    required String host,
    required String port,
    required String username,
    required String token,
  }) async {
    savedToken = token;
  }
}

void main() {
  group('RemoteConnectionRepository', () {
    test(
      'autentica pelo contrato v1 e mantém o token apenas na sessão',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'status': 'authorized', 'token': 'token-seguro'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final session = ApiSession(client: client);
        final storage = _FakeSecureStorageService();
        final repository = RemoteConnectionRepository(
          session: session,
          secureStorage: storage,
        );

        final attempt = await repository.connect(
          ip: '192.168.0.10',
          port: '8443',
          operatorName: 'Marcos Silva',
          username: 'guarda',
          password: 'segredo',
        );
        final connection = (attempt as ConnectionAuthorized).connection;

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://192.168.0.10:8443/api/mobile/login',
        );
        expect(jsonDecode(captured.body), {
          'device_id': 'c3a7e4b2-8f91-4d32-bb15-998877665544',
          'device_name': 'FaceTrack Mobile c3a7e4b2',
          'username': 'guarda',
          'password': 'segredo',
        });
        expect(connection.address, '192.168.0.10:8443');
        expect(session.accessToken, 'token-seguro');
        expect(storage.savedToken, 'token-seguro');

        session.dispose();
      },
    );

    test('propaga a mensagem FastAPI de autenticação inválida', () async {
      final session = ApiSession(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'detail': {
                'error': {
                  'code': 'INVALID_CREDENTIALS',
                  'message': 'Credenciais recusadas pelo servidor.',
                },
              },
            }),
            401,
          ),
        ),
      );
      final repository = RemoteConnectionRepository(
        session: session,
        secureStorage: _FakeSecureStorageService(),
      );

      expect(
        () => repository.connect(
          ip: '10.0.0.2',
          port: '8443',
          operatorName: 'Fiscal 01',
          username: 'x',
          password: 'y',
        ),
        throwsA(
          isA<ConnectionException>().having(
            (error) => error.message,
            'message',
            'Credenciais recusadas pelo servidor.',
          ),
        ),
      );

      session.dispose();
    });

    test(
      'usa X-Pairing-Secret no polling e consome o token aprovado',
      () async {
        var requestCount = 0;
        late http.Request statusRequest;
        final session = ApiSession(
          client: MockClient((request) async {
            requestCount++;
            if (requestCount == 1) {
              return http.Response(
                jsonEncode({
                  'status': 'pending_approval',
                  'pairing_secret': 'segredo-temporario',
                  'expires_in_seconds': 900,
                }),
                200,
              );
            }
            statusRequest = request;
            return http.Response(
              jsonEncode({'status': 'authorized', 'token': 'token-final'}),
              200,
            );
          }),
        );
        final storage = _FakeSecureStorageService();
        final repository = RemoteConnectionRepository(
          session: session,
          secureStorage: storage,
        );

        final initial = await repository.connect(
          ip: 'facetrack.local',
          port: '8443',
          operatorName: 'Fiscal 01',
          username: 'fiscal',
          password: 'senha',
        );
        expect(initial, isA<ConnectionPendingApproval>());

        final approved = await repository.pollApproval();

        expect(approved, isA<ConnectionAuthorized>());
        expect(statusRequest.headers['x-pairing-secret'], 'segredo-temporario');
        expect(statusRequest.url.queryParameters['device_id'], isNotEmpty);
        expect(storage.savedToken, 'token-final');

        session.dispose();
      },
    );
  });
}
