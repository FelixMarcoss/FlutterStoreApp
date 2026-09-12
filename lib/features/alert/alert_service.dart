import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../detections/data/models/detection.dart';

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
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

/// Centraliza vibração contínua + notificação nativa até o segurança
/// confirmar ("OK") que viu o alerta de pessoa com histórico de furto.
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

  bool _initialized = false;

  static const _alertChannelId = 'sentinela_alertas_urgentes';
  static const _alertChannelName = 'Alertas de segurança';
  static const _alertNotificationId = 1001;
  static const _foregroundServiceId = 256;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  bool get _supportsNativeAlerts => _isAndroid || _isIOS;

  Future<void> init() async {
    if (_initialized || !_supportsNativeAlerts) return;

    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
      );

      const channel = AndroidNotificationChannel(
        _alertChannelId,
        _alertChannelName,
        description: 'Pessoa com histórico de furto detectada pela câmera.',
        importance: Importance.max,
        playSound: true,
        // A vibração do alerta é controlada manualmente (loop até o "OK"),
        // não pela vibração padrão do canal.
        enableVibration: false,
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
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
        notificationTitle: 'Sentinela ativo',
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
  /// alta prioridade com full-screen intent, simulando o alerta que o
  /// segurança precisa confirmar.
  Future<void> startAlert(Detection detection) async {
    if (!_supportsNativeAlerts) return;

    try {
      if (await Vibration.hasVibrator()) {
        // repeat: 1 → repete a partir do índice 1 do pattern indefinidamente
        // até Vibration.cancel() ser chamado no "OK".
        unawaited(Vibration.vibrate(
          pattern: const [0, 800, 400, 800],
          repeat: 1,
        ));
      }
    } catch (e) {
      debugPrint('AlertService.startAlert falhou ao vibrar: $e');
    }

    try {
      await _notifications.show(
        id: _alertNotificationId,
        title: 'Pessoa com histórico de furto detectada',
        body: '${detection.displayCode} — ${detection.cameraLocation}',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannelId,
            _alertChannelName,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
          ),
          iOS: DarwinNotificationDetails(
            interruptionLevel: InterruptionLevel.critical,
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
    if (!_supportsNativeAlerts) return;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _notifications.cancel(id: _alertNotificationId);
    } catch (_) {}
  }
}
