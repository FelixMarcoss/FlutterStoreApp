import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sentinela_app/core/storage/secure_storage_service.dart';
import 'package:sentinela_app/core/theme/app_theme.dart';
import 'package:sentinela_app/features/alert/alert_audio_service.dart';
import 'package:sentinela_app/features/settings/cubit/alert_preferences_cubit.dart';
import 'package:sentinela_app/features/settings/data/models/alert_tone.dart';
import 'package:sentinela_app/features/settings/view/alert_preferences_screen.dart';

class _MockSecureStorageService extends Mock implements SecureStorageService {}

class _MockAlertAudioController extends Mock implements AlertAudioController {}

void main() {
  late _MockSecureStorageService storage;

  setUpAll(() {
    registerFallbackValue(AlertTone.electronicOne);
  });

  setUp(() {
    storage = _MockSecureStorageService();
    when(() => storage.readAlertTone()).thenAnswer((_) async => null);
    when(() => storage.saveAlertTone(any())).thenAnswer((_) async {});
    when(() => storage.readAlertVolume()).thenAnswer((_) async => null);
    when(() => storage.saveAlertVolume(any())).thenAnswer((_) async {});
  });

  blocTest<AlertPreferencesCubit, AlertPreferencesState>(
    'carrega os padrões de som e volume quando não há preferência salva',
    build: () => AlertPreferencesCubit(storage: storage),
    act: (cubit) => cubit.load(),
    expect: () => const [AlertPreferencesState(isLoaded: true)],
  );

  testWidgets(
    'informa que todos os níveis disparam alerta sem oferecer filtro',
    (tester) async {
      final cubit = AlertPreferencesCubit(storage: storage);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: BlocProvider.value(
            value: cubit,
            child: const AlertPreferencesScreen(),
          ),
        ),
      );

      expect(find.text('Alertas para todos os riscos'), findsOneWidget);
      expect(find.byKey(const Key('alerts_high_only')), findsNothing);
      expect(find.byKey(const Key('alerts_high_medium')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permite escolher um dos sons internos pelo dropdown', (
    tester,
  ) async {
    final cubit = AlertPreferencesCubit(storage: storage);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: BlocProvider.value(
          value: cubit,
          child: const AlertPreferencesScreen(),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final dropdown = find.byKey(const Key('alert_tone_dropdown'));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alerta eletrônico 2').last);
    await tester.pumpAndSettle();

    expect(cubit.state.tone, AlertTone.electronicTwo);
    verify(() => storage.saveAlertTone('electronic_two')).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('testa o som em loop e permite pará-lo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = AlertPreferencesCubit(storage: storage);
    final audio = _MockAlertAudioController();
    when(
      () => audio.playLoop(any(), volume: any(named: 'volume')),
    ).thenAnswer((_) async {});
    when(() => audio.stop()).thenAnswer((_) async {});
    when(() => audio.setVolume(any())).thenAnswer((_) async {});
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: BlocProvider.value(
          value: cubit,
          child: AlertPreferencesScreen(audioController: audio),
        ),
      ),
    );

    final preview = find.byKey(const Key('alert_sound_preview_button'));
    await tester.scrollUntilVisible(
      preview,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.pump();

    verify(
      () => audio.playLoop(AlertTone.electronicOne, volume: 0.8),
    ).called(1);
    expect(find.text('PARAR TESTE'), findsOneWidget);

    await tester.tap(preview);
    await tester.pump();
    verify(() => audio.stop()).called(1);
    expect(find.text('TESTAR SOM'), findsOneWidget);
  });
}
