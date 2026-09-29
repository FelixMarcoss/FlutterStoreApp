import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela_app/features/detections/cubit/detections_cubit.dart';
import 'package:sentinela_app/features/detections/data/models/detection.dart';
import 'package:sentinela_app/features/detections/data/models/detection_status.dart';
import 'package:sentinela_app/features/detections/data/repositories/detection_repository.dart';

class _MockDetectionRepository extends Mock implements DetectionRepository {}

Detection _detection(
  String id, {
  DetectionStatus status = DetectionStatus.newPerson,
}) {
  return Detection(
    id: id,
    displayCode: 'Pessoa #$id',
    status: status,
    detectedAt: DateTime(2026, 1, 1),
    cameraLocation: 'Entrada principal',
    occurrenceHistory: const [],
  );
}

void main() {
  late _MockDetectionRepository repository;
  late StreamController<Detection> alertsController;

  setUp(() {
    repository = _MockDetectionRepository();
    alertsController = StreamController<Detection>.broadcast();
    when(
      () => repository.alertsStream,
    ).thenAnswer((_) => alertsController.stream);
    when(
      () => repository.loadRecent(limit: any(named: 'limit')),
    ).thenAnswer((_) async => const []);
  });

  tearDown(() => alertsController.close());

  group('DetectionsCubit', () {
    blocTest<DetectionsCubit, DetectionsState>(
      'adiciona à lista quando um alerta chega pela stream',
      build: () => DetectionsCubit(detectionRepository: repository),
      act: (cubit) => alertsController.add(
        _detection('live-1', status: DetectionStatus.knownThief),
      ),
      expect: () => [
        isA<DetectionsState>().having(
          (s) => s.detections.map((d) => d.id),
          'ids',
          ['live-1'],
        ),
      ],
    );

    blocTest<DetectionsCubit, DetectionsState>(
      'acknowledge marca acknowledgedAt na detecção correta',
      build: () => DetectionsCubit(detectionRepository: repository),
      seed: () =>
          DetectionsState(detections: [_detection('a'), _detection('b')]),
      act: (cubit) => cubit.acknowledge('a'),
      expect: () => [
        isA<DetectionsState>().having(
          (s) => s.detections.firstWhere((d) => d.id == 'a').acknowledgedAt,
          'acknowledgedAt de a',
          isNotNull,
        ),
      ],
    );

    test('setFilter filtra filteredDetections por status', () async {
      final cubit = DetectionsCubit(detectionRepository: repository);
      alertsController
        ..add(_detection('a', status: DetectionStatus.knownThief))
        ..add(_detection('b', status: DetectionStatus.newPerson));
      await Future<void>.delayed(Duration.zero);

      expect(
        cubit.state.detections,
        containsAll(<Detection>[
          _detection('a', status: DetectionStatus.knownThief),
          _detection('b', status: DetectionStatus.newPerson),
        ]),
      );

      cubit.setFilter(DetectionStatus.knownThief);
      expect(cubit.state.filteredDetections.map((d) => d.id), ['a']);

      cubit.setFilter(null);
      expect(cubit.state.filteredDetections.length, 2);

      await cubit.close();
    });

    test(
      'histórico atualiza o mesmo event_id e limpa metadados da Super Cloud',
      () async {
        final oldEvent = Detection(
          id: 'evt-same',
          displayCode: 'Pessoa antiga',
          status: DetectionStatus.suspect,
          detectedAt: DateTime(2026, 9, 25, 10),
          cameraLocation: 'Câmera antiga',
          notes: 'Dado privado antigo',
          registeredBy: 'Autor antigo',
          createdAt: DateTime(2026, 9, 20),
          occurrenceHistory: const [],
        );
        final cloudEvent = Detection(
          id: 'evt-same',
          displayCode: 'Ocorrência #91',
          status: DetectionStatus.suspect,
          detectedAt: DateTime(2026, 9, 25, 11),
          cameraLocation: '',
          originStoreName: 'Loja Origem',
          occurrenceNumber: 91,
          occurrenceHistory: const [],
          isSilent: true,
        );
        when(
          () => repository.loadRecent(limit: any(named: 'limit')),
        ).thenAnswer((_) async => [cloudEvent]);
        final cubit = DetectionsCubit(detectionRepository: repository);
        alertsController.add(oldEvent);
        await Future<void>.delayed(Duration.zero);
        cubit.acknowledge('evt-same');

        await cubit.loadRecent();

        expect(cubit.state.detections, hasLength(1));
        final stored = cubit.state.detections.single;
        expect(stored.isSuperCloud, isTrue);
        expect(stored.notes, isNull);
        expect(stored.registeredBy, isNull);
        expect(stored.createdAt, isNull);
        expect(stored.acknowledgedAt, isNotNull);
        await cubit.close();
      },
    );
  });
}
