import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../detections/data/models/detection.dart';
import '../detections/data/models/detection_status.dart';
import '../settings/data/models/alert_tone.dart';
import 'alert_audio_service.dart';

/// Handler quase vazio: hoje só existe para manter o serviço em primeiro
/// plano vivo (o que evita o Android suspender o processo e cortar o Timer
/// mockado em [MockDetectionRepository]). Quando existir uma conexão real
/// (WebSocket com o software principal), ela deve rodar AQUI dentro —
/// isolates de foreground service sobrevivem bem mais tempo em segundo
/// plano do que o isolate principal da UI.
@pragma('vm:entry-point')
void sentinelaForegroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_SentinelaTaskHandler());
}

class _SentinelaTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // stopWithTask encerra o serviço quando o app é removido dos recentes.
    // O cancelamento explícito evita que um padrão repetitivo sobreviva ao
    // encerramento da interface em alguns fabricantes Android.
    try {
      await Vibration.cancel();
    } catch (_) {}
    // Remove tanto o alerta biométrico quanto a notificação persistente do
    // serviço quando o usuário elimina o app pela tela de recentes.
    try {
      await FlutterLocalNotificationsPlugin().cancelAll();
    } catch (_) {}
  }
}

/// Centraliza vibração contínua + notificação nativa até o operador confirmar
/// que viu qualquer alerta recebido em tempo real.
///
/// Tudo aqui é protegido por [_supportsNativeAlerts]: em Windows/Web (as
/// únicas plataformas disponíveis para rodar `flutter run` nesta máquina de
/// desenvolvimento) essas chamadas são no-op, então a UI continua
/// funcionando normalmente para conferir as telas.
///
/// Limitação de plataforma: iOS restringe execução em segundo plano sem
/// push remoto (e aqui não há internet no dispositivo, só rede local) — o
/// foreground service abaixo é uma solução específica do Android. No iOS o
/// alerta é garantido apenas com o app em primeiro plano.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AlertAudioController _audio = AlertAudioService.instance;
  final _acknowledgementsController = StreamController<void>.broadcast();

  bool _initialized = false;

  // Canais Android são imutáveis. A versão v4 cria um canal explicitamente
  // silencioso: os MP3 internos são reproduzidos pelo player do FaceTrack.
  static const _alertChannelId = 'facetrack_alertas_silenciosos_v4';
  static const _alertChannelName = 'Alertas de segurança';
  static const _alertNotificationId = 1001;
  static const _foregroundServiceId = 256;
  static const _acknowledgeActionId = 'sentinela_acknowledge_alert';
  static const _alertCategoryId = 'sentinela_alert_category';

  Stream<void> get acknowledgementRequests =>
      _acknowledgementsController.stream;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _supportsNativeAlerts => _isAndroid || _isIOS;

  Future<void> init() async {
    if (_initialized || !_supportsNativeAlerts) return;

    try {
      await _notifications.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            notificationCategories: [
              DarwinNotificationCategory(
                _alertCategoryId,
                actions: [
                  DarwinNotificationAction.plain(
                    _acknowledgeActionId,
                    'Confirmar e parar',
                    options: {DarwinNotificationActionOption.foreground},
                  ),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.actionId == _acknowledgeActionId) {
            _acknowledgementsController.add(null);
          }
        },
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _alertChannelId,
          _alertChannelName,
          description: 'Alertas visuais do FaceTrack.',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();

      if (_isAndroid) {
        FlutterForegroundTask.initCommunicationPort();
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'sentinela_monitoramento',
            channelName: 'Monitoramento ativo',
            channelDescription:
                'Mantém a conexão com o sistema principal ativa em segundo plano.',
            onlyAlertOnce: true,
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: false,
            playSound: false,
          ),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.nothing(),
            autoRunOnBoot: false,
            allowWakeLock: true,
            allowWifiLock: true,
          ),
        );
      }

      _initialized = true;
    } catch (e) {
      debugPrint('AlertService.init falhou (seguindo sem alertas nativos): $e');
    }
  }

  /// Inicia o serviço em primeiro plano do Android assim que o segurança
  /// se conecta, para reduzir a chance do sistema encerrar o app enquanto
  /// ele está em segundo plano/tela bloqueada.
  Future<void> startMonitoring({required String connectionAddress}) async {
    if (!_supportsNativeAlerts || !_isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: _foregroundServiceId,
        notificationTitle: 'FaceTrack ativo',
        notificationText: 'Monitorando conexão com $connectionAddress',
        callback: sentinelaForegroundTaskCallback,
      );
    } catch (e) {
      debugPrint('AlertService.startMonitoring falhou: $e');
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('AlertService.stopMonitoring falhou: $e');
    }
  }

  /// Dispara vibração em loop (só cessa com [stopAlert]) + notificação de
  /// alta prioridade com full-screen intent para o alerta que o operador
  /// precisa confirmar.
  Future<void> startAlert(
    Detection detection, {
    AlertTone tone = AlertTone.electronicOne,
    double volume = 0.8,
  }) async {
    if (!_supportsNativeAlerts) return;

    try {
      await _audio.playLoop(tone, volume: volume);
    } catch (e) {
      debugPrint('AlertService.startAlert falhou ao reproduzir áudio: $e');
    }

    try {
      if (await Vibration.hasVibrator()) {
        // Baixo, médio e alto usam o mesmo padrão contínuo até o fiscal
        // confirmar ou silenciar o alerta.
        unawaited(
          Vibration.vibrate(pattern: const [0, 800, 400, 800], repeat: 1),
        );
      }
    } catch (e) {
      debugPrint('AlertService.startAlert falhou ao vibrar: $e');
    }

    try {
      await _notifications.show(
        id: _alertNotificationId,
        title: detection.isSuperCloud
            ? 'Ocorrência da rede detectada'
            : detection.status == DetectionStatus.knownThief
            ? 'Suspeito de alto risco detectado'
            : detection.status == DetectionStatus.suspect
            ? 'Pessoa de risco médio detectada'
            : 'Pessoa de risco baixo detectada',
        body: [
          detection.isSuperCloud
              ? 'Ocorrência #${detection.occurrenceNumber}'
              : detection.displayCode,
          if (detection.availableLocation != null) detection.availableLocation!,
          'Abra para conferir.',
        ].join(' — '),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannelId,
            _alertChannelName,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction(
                _acknowledgeActionId,
                'CONFIRMAR E PARAR',
                showsUserInterface: true,
                cancelNotification: false,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: false,
            interruptionLevel: InterruptionLevel.active,
            categoryIdentifier: _alertCategoryId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('AlertService.startAlert falhou ao notificar: $e');
    }
  }

  /// Chamado quando o segurança confirma ("OK, verifiquei") — para a
  /// vibração e remove a notificação.
  Future<void> stopAlert() async {
    try {
      await _audio.stop();
    } catch (_) {}
    if (!_supportsNativeAlerts) return;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _notifications.cancel(id: _alertNotificationId);
    } catch (_) {}
  }
}
