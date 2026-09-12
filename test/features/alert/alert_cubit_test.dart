import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela_app/features/alert/alert_service.dart';
import 'package:sentinela_app/features/alert/cubit/alert_cubit.dart';
import 'package:sentinela_app/features/detections/cubit/detections_cubit.dart';
import 'package:sentinela_app/features/detections/data/models/detection.dart';
import 'package:sentinela_app/features/detections/data/models/detection_status.dart';
import 'package:sentinela_app/features/detections/data/repositories/detection_repository.dart';

class _MockDetectionRepository extends Mock implements DetectionRepository {}

class _MockDetectionsCubit extends MockCubit<DetectionsState>
    implements DetectionsCubit {}

class _MockAlertService extends Mock implements AlertService {}

Detection _detection(String id, {DetectionStatus status = DetectionStatus.knownThief}) {
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
  late _MockDetectionsCubit detectionsCubit;
  late _MockAlertService alertService;
  late StreamController<Detection> alertsController;

  setUpAll(() {
    // Detection é `final class` (não pode ser implementada por um Fake fora
    // do seu library) — usamos uma instância real como valor de fallback.
    registerFallbackValue(_detection('fallback'));
  });

  setUp(() {
    repository = _MockDetectionRepository();
    detectionsCubit = _MockDetectionsCubit();
    alertService = _MockAlertService();
    alertsController = StreamController<Detection>.broadcast();
    when(() => repository.alertsStream).thenAnswer((_) => alertsController.stream);
    when(() => alertService.startAlert(any())).thenAnswer((_) async {});
    when(() => alertService.stopAlert()).thenAnswer((_) async {});
    when(() => detectionsCubit.acknowledge(any())).thenReturn(null);
  });

  tearDown(() => alertsController.close());

  AlertCubit build() => AlertCubit(
        detectionRepository: repository,
        detectionsCubit: detectionsCubit,
        alertService: alertService,
      );

  group('AlertCubit', () {
    blocTest<AlertCubit, AlertState>(
      'enfileira e dispara o alerta (vibração/notificação) quando chega um '
      '"ladrão conhecido"',
      build: build,
      act: (cubit) => alertsController.add(_detection('t1')),
      expect: () => [
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', ['t1']),
      ],
      verify: (_) => verify(() => alertService.startAlert(any())).called(1),
    );

    blocTest<AlertCubit, AlertState>(
      'ignora detecções que não são "ladrão conhecido" (não dispara alerta)',
      build: build,
      act: (cubit) => alertsController.add(_detection('s1', status: DetectionStatus.suspect)),
      expect: () => <AlertState>[],
      verify: (_) => verifyNever(() => alertService.startAlert(any())),
    );

    blocTest<AlertCubit, AlertState>(
      'uma segunda detecção só entra na fila, sem reiniciar o alerta em '
      'andamento',
      build: build,
      act: (cubit) async {
        alertsController.add(_detection('t1'));
        await Future<void>.delayed(Duration.zero);
        alertsController.add(_detection('t2'));
      },
      expect: () => [
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', ['t1']),
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', ['t1', 't2']),
      ],
      verify: (_) => verify(() => alertService.startAlert(any())).called(1),
    );

    blocTest<AlertCubit, AlertState>(
      'acknowledgeCurrent esvazia a fila, para o alerta e confirma na '
      'DetectionsCubit quando só há um pendente',
      build: build,
      seed: () => AlertState(queue: [_detection('t1')]),
      act: (cubit) => cubit.acknowledgeCurrent(),
      expect: () => [
        isA<AlertState>().having((s) => s.queue, 'queue', isEmpty),
      ],
      verify: (_) {
        verify(() => alertService.stopAlert()).called(1);
        verify(() => detectionsCubit.acknowledge('t1')).called(1);
        verifyNever(() => alertService.startAlert(any()));
      },
    );

    blocTest<AlertCubit, AlertState>(
      'acknowledgeCurrent avança para o próximo da fila e reinicia o alerta '
      'para ele',
      build: build,
      seed: () => AlertState(queue: [_detection('t1'), _detection('t2')]),
      act: (cubit) => cubit.acknowledgeCurrent(),
      expect: () => [
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', ['t2']),
      ],
      verify: (_) {
        verify(() => alertService.stopAlert()).called(1);
        verify(() => detectionsCubit.acknowledge('t1')).called(1);
        verify(() => alertService.startAlert(any())).called(1);
      },
    );

    blocTest<AlertCubit, AlertState>(
      'reset limpa a fila e para o alerta (usado ao desconectar, para nunca '
      'deixar o aparelho vibrando sem tela para confirmar)',
      build: build,
      seed: () => AlertState(queue: [_detection('t1')]),
      act: (cubit) => cubit.reset(),
      expect: () => [
        isA<AlertState>().having((s) => s.queue, 'queue', isEmpty),
      ],
      verify: (_) => verify(() => alertService.stopAlert()).called(1),
    );

    blocTest<AlertCubit, AlertState>(
      'reset é um no-op (sem emitir nem parar alerta) quando a fila já está '
      'vazia',
      build: build,
      act: (cubit) => cubit.reset(),
      expect: () => <AlertState>[],
      verify: (_) => verifyNever(() => alertService.stopAlert()),
    );
  });
}
