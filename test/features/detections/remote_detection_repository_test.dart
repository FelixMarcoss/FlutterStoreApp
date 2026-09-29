import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sentinela_app/core/network/api_session.dart';
import 'package:sentinela_app/features/detections/data/models/detection.dart';
import 'package:sentinela_app/features/detections/data/models/detection_status.dart';
import 'package:sentinela_app/features/detections/data/repositories/remote_detection_repository.dart';

void main() {
  test('entrega a foto Base64 já incorporada ao evento', () async {
    var calls = 0;
    final bytes = <int>[1, 2, 3, 4];
    final session =
        ApiSession(
          client: MockClient((request) async {
            calls++;
            expect(request.headers['authorization'], 'Bearer token');
            return http.Response.bytes(
              bytes,
              200,
              headers: {'content-type': 'image/jpeg'},
            );
          }),
        )..establish(
          baseUri: Uri.parse('https://192.168.0.10:8443'),
          accessToken: 'token',
        );
    final repository = RemoteDetectionRepository(session: session);
    final detection = Detection(
      id: 'photo-id',
      displayCode: 'Pessoa #A231',
      status: DetectionStatus.knownThief,
      detectedAt: DateTime.utc(2026, 9, 13, 20, 12, 45),
      cameraId: 'camera-entrada-01',
      cameraLocation: 'Entrada principal',
      photoBytes: bytes,
      occurrenceHistory: const [],
    );

    expect(await repository.fetchPhoto(detection), bytes);
    expect(await repository.fetchPhoto(detection), bytes);
    expect(calls, 0);

    repository.dispose();
    session.dispose();
  });

  test('carrega histórico em silêncio com o contrato FaceTrack', () async {
    final photo = base64Encode(<int>[1, 2, 3, 4]);
    final session =
        ApiSession(
          client: MockClient((request) async {
            expect(request.url.path, '/api/mobile/events/recent');
            expect(request.headers['authorization'], 'Bearer token');
            return http.Response(
              jsonEncode({
                'status': 'success',
                'events': [
                  {
                    'type': 'FACE_RECOGNITION_ALERT',
                    'event_id': 'evt_1_abc',
                    'timestamp': '2026-09-23T12:20:34.567Z',
                    'confidence': 0.998,
                    'camera_name': 'Entrada Principal',
                    'is_silent': false,
                    'person': {
                      'id': 4,
                      'name': 'Pessoa monitorada',
                      'risk_level': 'high',
                      'notes': 'Abordagem com apoio',
                      'registered_photo_b64': photo,
                    },
                    'detection': {
                      'captured_face_b64': photo,
                      'bbox': [1, 2, 3, 4],
                    },
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        )..establish(
          baseUri: Uri.parse('https://facetrack.local:8000'),
          accessToken: 'token',
        );
    final repository = RemoteDetectionRepository(session: session);

    final history = await repository.loadRecent();

    expect(history, hasLength(1));
    expect(history.single.id, 'evt_1_abc');
    expect(history.single.status, DetectionStatus.knownThief);
    expect(history.single.isSilent, isTrue);
    expect(history.single.photoBytes, <int>[1, 2, 3, 4]);
    expect(history.single.registeredPhotoBytes, <int>[1, 2, 3, 4]);

    repository.dispose();
    session.dispose();
  });

  test('aceita o contrato 1.7.8 sem camera_name e bbox', () async {
    final session =
        ApiSession(
          client: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'events': [
                  {
                    'type': 'FACE_RECOGNITION_ALERT',
                    'event_id': 'evt_178_local',
                    'timestamp': '2026-09-25T12:20:34.567Z',
                    'confidence': 0.91,
                    'is_silent': false,
                    'person': {
                      'id': 8,
                      'name': 'Pessoa cadastrada',
                      'risk_level': 'high',
                      'origin_store_name': 'Loja Centro',
                      'registered_by': 'Maria',
                      'created_at': '2026-09-20T14:30:00Z',
                      'notes': 'Descrição completa do cadastro',
                      'registered_photo_b64': '',
                    },
                    'detection': {'captured_face_b64': ''},
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        )..establish(
          baseUri: Uri.parse('https://192.168.10.1:8443'),
          accessToken: 'token',
        );
    final repository = RemoteDetectionRepository(session: session);

    final event = (await repository.loadRecent()).single;

    expect(event.cameraLocation, isEmpty);
    expect(event.boundingBox, isNull);
    expect(event.originStoreName, 'Loja Centro');
    expect(event.registeredBy, 'Maria');
    expect(event.createdAt, DateTime.parse('2026-09-20T14:30:00Z').toLocal());
    expect(event.notes, 'Descrição completa do cadastro');
    expect(event.isSuperCloud, isFalse);
    expect(event.riskLabel, 'Alto risco');

    repository.dispose();
    session.dispose();
  });

  test('identifica Super Cloud e remove metadados privados', () async {
    final session =
        ApiSession(
          client: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'events': [
                  {
                    'type': 'FACE_RECOGNITION_ALERT',
                    'event_id': 'evt_cloud_91',
                    'timestamp': '2026-09-25T12:20:34.567Z',
                    'confidence': 0.87,
                    'is_silent': true,
                    'person': {
                      'id': 7,
                      'name': 'Ocorrência #91',
                      'risk_level': 'medium',
                      'occurrence_number': 91,
                      'origin_store_name': 'Loja Origem',
                      // Mesmo que um backend incorreto envie estes campos,
                      // o app não deve retê-los para eventos da rede.
                      'registered_by': 'Não deve persistir',
                      'created_at': '2026-09-20T14:30:00Z',
                      'notes': 'Não deve persistir',
                      'registered_photo_b64': '',
                    },
                    'detection': {'captured_face_b64': ''},
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        )..establish(
          baseUri: Uri.parse('https://192.168.10.1:8443'),
          accessToken: 'token',
        );
    final repository = RemoteDetectionRepository(session: session);

    final event = (await repository.loadRecent()).single;

    expect(event.isSuperCloud, isTrue);
    expect(event.occurrenceNumber, 91);
    expect(event.originStoreName, 'Loja Origem');
    expect(event.riskLabel, 'Risco não informado');
    expect(event.notes, isNull);
    expect(event.registeredBy, isNull);
    expect(event.createdAt, isNull);

    repository.dispose();
    session.dispose();
  });
}
