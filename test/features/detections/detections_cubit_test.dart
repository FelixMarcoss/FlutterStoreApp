import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela_app/features/detections/cubit/detections_cubit.dart';
import 'package:sentinela_app/features/detections/data/models/detection.dart';
import 'package:sentinela_app/features/detections/data/models/detection_status.dart';
import 'package:sentinela_app/features/detections/data/repositories/detection_repository.dart';

class _MockDetectionRepository extends Mock implements DetectionRepository {}

Detection _detection(String id, {DetectionStatus status = DetectionStatus.newPerson}) {
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
    when(() => repository.alertsStream).thenAnswer((_) => alertsController.stream);
  });

  tearDown(() => alertsController.close());

  group('DetectionsCubit', () {
    blocTest<DetectionsCubit, DetectionsState>(
      'emite [loading, success] com o histórico ao chamar fetchInitial',
      setUp: () => when(() => repository.fetchHistory())
          .thenAnswer((_) async => [_detection('a'), _detection('b')]),
      build: () => DetectionsCubit(detectionRepository: repository),
      act: (cubit) => cubit.fetchInitial(),
      expect: () => [
        isA<DetectionsState>().having((s) => s.status, 'status', DetectionsStatus.loading),
        isA<DetectionsState>()
            .having((s) => s.status, 'status', DetectionsStatus.success)
            .having((s) => s.detections.length, 'quantidade', 2),
      ],
    );

    blocTest<DetectionsCubit, DetectionsState>(
      'emite [failure] quando o histórico falha',
      setUp: () => when(() => repository.fetchHistory()).thenThrow(Exception('erro de rede')),
      build: () => DetectionsCubit(detectionRepository: repository),
      act: (cubit) => cubit.fetchInitial(),
      expect: () => [
        isA<DetectionsState>().having((s) => s.status, 'status', DetectionsStatus.loading),
        isA<DetectionsState>().having((s) => s.status, 'status', DetectionsStatus.failure),
      ],
    );

    blocTest<DetectionsCubit, DetectionsState>(
      'adiciona à lista quando um alerta chega pela stream',
      build: () => DetectionsCubit(detectionRepository: repository),
      act: (cubit) => alertsController.add(_detection('live-1', status: DetectionStatus.knownThief)),
      expect: () => [
        isA<DetectionsState>().having((s) => s.detections.map((d) => d.id), 'ids', ['live-1']),
      ],
    );

    blocTest<DetectionsCubit, DetectionsState>(
      'acknowledge marca acknowledgedAt na detecção correta',
      build: () => DetectionsCubit(detectionRepository: repository),
      seed: () => DetectionsState(detections: [_detection('a'), _detection('b')]),
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
      when(() => repository.fetchHistory()).thenAnswer((_) async => [
            _detection('a', status: DetectionStatus.knownThief),
            _detection('b', status: DetectionStatus.newPerson),
          ]);
      final cubit = DetectionsCubit(detectionRepository: repository);
      await cubit.fetchInitial();

      cubit.setFilter(DetectionStatus.knownThief);
      expect(cubit.state.filteredDetections.map((d) => d.id), ['a']);

      cubit.setFilter(null);
      expect(cubit.state.filteredDetections.length, 2);

      await cubit.close();
    });
  });
}
