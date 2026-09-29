import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela_app/core/storage/secure_storage_service.dart';
import 'package:sentinela_app/core/theme/app_theme.dart';
import 'package:sentinela_app/features/alert/alert_service.dart';
import 'package:sentinela_app/features/alert/cubit/alert_cubit.dart';
import 'package:sentinela_app/features/alert/view/alert_screen.dart';
import 'package:sentinela_app/features/detections/cubit/detections_cubit.dart';
import 'package:sentinela_app/features/detections/data/models/detection.dart';
import 'package:sentinela_app/features/detections/data/models/detection_status.dart';
import 'package:sentinela_app/features/detections/data/repositories/detection_repository.dart';
import 'package:sentinela_app/features/settings/cubit/alert_preferences_cubit.dart';
import 'package:sentinela_app/features/settings/data/models/alert_tone.dart';

class _MockDetectionRepository extends Mock implements DetectionRepository {}

class _MockDetectionsCubit extends MockCubit<DetectionsState>
    implements DetectionsCubit {}

class _MockAlertService extends Mock implements AlertService {}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

Detection _detection(
  String id, {
  DetectionStatus status = DetectionStatus.knownThief,
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
  late _MockDetectionsCubit detectionsCubit;
  late _MockAlertService alertService;
  late StreamController<Detection> alertsController;

  setUpAll(() {
    // Detection é `final class` (não pode ser implementada por um Fake fora
    // do seu library) — usamos uma instância real como valor de fallback.
    registerFallbackValue(_detection('fallback'));
    registerFallbackValue(AlertTone.electronicOne);
  });

  setUp(() {
    repository = _MockDetectionRepository();
    detectionsCubit = _MockDetectionsCubit();
    alertService = _MockAlertService();
    alertsController = StreamController<Detection>.broadcast();
    when(
      () => repository.alertsStream,
    ).thenAnswer((_) => alertsController.stream);
    when(
      () => alertService.startAlert(
        any(),
        tone: any(named: 'tone'),
        volume: any(named: 'volume'),
      ),
    ).thenAnswer((_) async {});
    when(() => alertService.stopAlert()).thenAnswer((_) async {});
    when(() => detectionsCubit.acknowledge(any())).thenReturn(null);
  });

  tearDown(() => alertsController.close());

  AlertCubit build({AlertPreferencesCubit? preferencesCubit}) => AlertCubit(
    detectionRepository: repository,
    detectionsCubit: detectionsCubit,
    preferencesCubit: preferencesCubit,
    alertService: alertService,
  );

  group('AlertCubit', () {
    blocTest<AlertCubit, AlertState>(
      'enfileira e dispara o alerta (vibração/notificação) quando chega um '
      'alto risco',
      build: build,
      act: (cubit) => alertsController.add(_detection('t1')),
      expect: () => [
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', [
          't1',
        ]),
      ],
      verify: (_) => verify(
        () => alertService.startAlert(
          any(),
          tone: any(named: 'tone'),
          volume: any(named: 'volume'),
        ),
      ).called(1),
    );

    blocTest<AlertCubit, AlertState>(
      'risco médio também entra na fila e dispara o alerta',
      build: build,
      act: (cubit) => alertsController.add(
        _detection('s1', status: DetectionStatus.suspect),
      ),
      expect: () => [
        isA<AlertState>().having((s) => s.current?.id, 'current', 's1'),
      ],
      verify: (_) => verify(
        () => alertService.startAlert(
          any(),
          tone: any(named: 'tone'),
          volume: any(named: 'volume'),
        ),
      ).called(1),
    );

    blocTest<AlertCubit, AlertState>(
      'risco baixo também entra na fila e dispara o alerta',
      build: build,
      act: (cubit) => alertsController.add(
        _detection('l1', status: DetectionStatus.newPerson),
      ),
      expect: () => [
        isA<AlertState>().having((s) => s.current?.id, 'current', 'l1'),
      ],
      verify: (_) => verify(
        () => alertService.startAlert(
          any(),
          tone: any(named: 'tone'),
          volume: any(named: 'volume'),
        ),
      ).called(1),
    );

    test('usa o som escolhido pelo fiscal ao iniciar o alerta', () async {
      final storage = _MockSecureStorageService();
      when(() => storage.saveAlertTone(any())).thenAnswer((_) async {});
      final preferences = AlertPreferencesCubit(storage: storage);
      when(() => storage.saveAlertVolume(any())).thenAnswer((_) async {});
      await preferences.selectTone(AlertTone.electronicTwo);
      await preferences.selectVolume(0.35);
      final cubit = build(preferencesCubit: preferences);

      alertsController.add(_detection('tone-alarm'));
      await Future<void>.delayed(Duration.zero);

      verify(
        () => alertService.startAlert(
          any(),
          tone: AlertTone.electronicTwo,
          volume: 0.35,
        ),
      ).called(1);

      await cubit.close();
      await preferences.close();
    });

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
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', [
          't1',
        ]),
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', [
          't1',
          't2',
        ]),
      ],
      verify: (_) => verify(
        () => alertService.startAlert(
          any(),
          tone: any(named: 'tone'),
          volume: any(named: 'volume'),
        ),
      ).called(1),
    );

    blocTest<AlertCubit, AlertState>(
      'silenceCurrent para o alarme sem remover o alerta da fila',
      build: build,
      seed: () => AlertState(queue: [_detection('t1')]),
      act: (cubit) => cubit.silenceCurrent(),
      expect: () => [
        isA<AlertState>()
            .having((s) => s.current?.id, 'current', 't1')
            .having((s) => s.isSilenced, 'isSilenced', isTrue),
      ],
      verify: (_) {
        verify(() => alertService.stopAlert()).called(1);
        verifyNever(() => detectionsCubit.acknowledge(any()));
      },
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
        verifyNever(
          () => alertService.startAlert(
            any(),
            tone: any(named: 'tone'),
            volume: any(named: 'volume'),
          ),
        );
      },
    );

    blocTest<AlertCubit, AlertState>(
      'acknowledgeCurrent avança para o próximo da fila e reinicia o alerta '
      'para ele',
      build: build,
      seed: () => AlertState(queue: [_detection('t1'), _detection('t2')]),
      act: (cubit) => cubit.acknowledgeCurrent(),
      expect: () => [
        isA<AlertState>().having((s) => s.queue.map((d) => d.id), 'ids', [
          't2',
        ]),
      ],
      verify: (_) {
        verify(() => alertService.stopAlert()).called(1);
        verify(() => detectionsCubit.acknowledge('t1')).called(1);
        verify(
          () => alertService.startAlert(
            any(),
            tone: any(named: 'tone'),
            volume: any(named: 'volume'),
          ),
        ).called(1);
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

    test('confirma o alerta quando a ação da notificação solicita', () async {
      final requests = StreamController<void>();
      final cubit = AlertCubit(
        detectionRepository: repository,
        detectionsCubit: detectionsCubit,
        alertService: alertService,
        acknowledgementRequests: requests.stream,
      );

      alertsController.add(_detection('notification'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.current?.id, 'notification');

      requests.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.queue, isEmpty);
      verify(() => alertService.stopAlert()).called(1);
      verify(() => detectionsCubit.acknowledge('notification')).called(1);

      await cubit.close();
      await requests.close();
    });

    testWidgets('tela de alerta exibe o novo layout e permite silenciar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final cubit = build();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: BlocProvider.value(value: cubit, child: const AlertScreen()),
        ),
      );

      alertsController.add(
        Detection(
          id: 'evt_visual_1',
          displayCode: 'Pessoa teste',
          status: DetectionStatus.knownThief,
          detectedAt: DateTime(2026, 1, 1),
          cameraLocation: 'Entrada principal',
          occurrenceHistory: const [],
        ),
      );
      await tester.pump();

      expect(find.text('FaceTrack'), findsOneWidget);
      expect(find.text('SUSPEITO DETECTADO'), findsOneWidget);
      expect(find.text('DADOS DO SUSPEITO'), findsOneWidget);
      expect(find.text('INFORMAÇÕES DETALHADAS'), findsOneWidget);
      expect(find.textContaining('evt_'), findsNothing);
      expect(find.byKey(const Key('alert_silence_button')), findsOneWidget);
      expect(find.byKey(const Key('alert_ok_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('alert_silence_button')));
      await tester.pump();

      expect(cubit.state.isSilenced, isTrue);
      expect(find.text('ALARME\nSILENCIADO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'tela diferencia ocorrência da Super Cloud sem dados privados',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final cubit = build();
        addTearDown(cubit.close);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: BlocProvider.value(value: cubit, child: const AlertScreen()),
          ),
        );

        alertsController.add(
          Detection(
            id: 'evt-cloud-91',
            displayCode: 'Ocorrência #91',
            status: DetectionStatus.suspect,
            detectedAt: DateTime(2026, 9, 25, 12, 20),
            cameraLocation: '',
            originStoreName: 'Loja Origem',
            occurrenceNumber: 91,
            confidence: 0.87,
            occurrenceHistory: const [],
          ),
        );
        await tester.pump();

        expect(find.text('OCORRÊNCIA DA REDE'), findsOneWidget);
        expect(find.text('DADOS DA OCORRÊNCIA'), findsOneWidget);
        expect(find.text('#91'), findsOneWidget);
        expect(find.text('Loja Origem'), findsOneWidget);
        expect(find.text('RISCO NÃO INFORMADO'), findsWidgets);
        expect(find.textContaining('evt-cloud-91'), findsNothing);
        expect(find.text('Cadastrado por'), findsNothing);
        expect(find.text('Cadastrado em'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
