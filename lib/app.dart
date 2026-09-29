import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/network/api_session.dart';
import 'features/alert/alert_service.dart';
import 'features/alert/cubit/alert_cubit.dart';
import 'features/auth/cubit/session_cubit.dart';
import 'features/auth/data/models/connection_config.dart';
import 'features/auth/data/repositories/connection_repository.dart';
import 'features/auth/data/repositories/mock_connection_repository.dart';
import 'features/auth/data/repositories/remote_connection_repository.dart';
import 'features/auth/view/reconnecting_screen.dart';
import 'features/detections/cubit/detections_cubit.dart';
import 'features/detections/data/repositories/detection_repository.dart';
import 'features/detections/data/repositories/mock_detection_repository.dart';
import 'features/detections/data/repositories/remote_detection_repository.dart';
import 'features/settings/cubit/alert_preferences_cubit.dart';
import 'routing/app_router.dart';

class App extends StatefulWidget {
  const App({super.key, this.apiSession});

  final ApiSession? apiSession;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final ConnectionRepository _connectionRepository;
  late final DetectionRepository _detectionRepository;
  ApiSession? _apiSession;
  late final SessionCubit _sessionCubit;
  late final DetectionsCubit _detectionsCubit;
  late final AlertPreferencesCubit _alertPreferencesCubit;
  late final AlertCubit _alertCubit;
  late final GoRouter _router;
  StreamSubscription<int>? _terminalSocketSubscription;
  StreamSubscription<bool>? _realtimeConnectionSubscription;
  bool _hadRealtimeConnection = false;
  bool _showReconnectScreen = false;

  @override
  void initState() {
    super.initState();
    const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);
    if (useMocks) {
      _connectionRepository = MockConnectionRepository();
      _detectionRepository = MockDetectionRepository();
    } else {
      final session = widget.apiSession ?? ApiSession();
      _apiSession = session;
      const apiScheme = String.fromEnvironment(
        'API_SCHEME',
        defaultValue: 'https',
      );
      _connectionRepository = RemoteConnectionRepository(
        session: session,
        scheme: apiScheme,
      );
      _detectionRepository = RemoteDetectionRepository(session: session);
    }

    _sessionCubit = SessionCubit(connectionRepository: _connectionRepository);
    _detectionsCubit = DetectionsCubit(
      detectionRepository: _detectionRepository,
    );
    _alertPreferencesCubit = AlertPreferencesCubit();
    unawaited(_alertPreferencesCubit.load());
    _alertCubit = AlertCubit(
      detectionRepository: _detectionRepository,
      detectionsCubit: _detectionsCubit,
      preferencesCubit: _alertPreferencesCubit,
    );
    _router = buildAppRouter(sessionCubit: _sessionCubit);
    if (_detectionRepository is RealtimeConnectionReporter) {
      final reporter = _detectionRepository as RealtimeConnectionReporter;
      _terminalSocketSubscription = reporter.terminalCloseCodes.listen((code) {
        if (code == 4001 || code == 4002 || code == 4003) {
          if (mounted && _showReconnectScreen) {
            setState(() => _showReconnectScreen = false);
          }
          _hadRealtimeConnection = false;
          unawaited(_sessionCubit.disconnect());
        }
      });
      _realtimeConnectionSubscription = reporter.realtimeConnectionChanges
          .listen((connected) {
            if (connected) {
              _hadRealtimeConnection = true;
              if (mounted && _showReconnectScreen) {
                setState(() => _showReconnectScreen = false);
                // Recupera silenciosamente alertas que possam ter ocorrido
                // enquanto o telefone esteve fora do alcance do Wi-Fi.
                unawaited(_detectionsCubit.loadRecent());
              }
              return;
            }
            // Depois que o canal já esteve operacional, bloqueia a interface
            // e mantém a sessão para que o repositório tente reconectar no
            // mesmo IP e porta com seu backoff automático.
            if (_hadRealtimeConnection && _sessionCubit.state != null) {
              unawaited(_alertCubit.reset());
              if (mounted && !_showReconnectScreen) {
                setState(() => _showReconnectScreen = true);
              }
            }
          });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_sessionCubit.restore());
    });
  }

  @override
  void dispose() {
    unawaited(_terminalSocketSubscription?.cancel());
    unawaited(_realtimeConnectionSubscription?.cancel());
    unawaited(AlertService.instance.stopAlert());
    _sessionCubit.close();
    _detectionsCubit.close();
    _alertPreferencesCubit.close();
    _alertCubit.close();
    _detectionRepository.dispose();
    _apiSession?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _connectionRepository,
      child: RepositoryProvider.value(
        value: _detectionRepository,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: _sessionCubit),
            BlocProvider.value(value: _detectionsCubit),
            BlocProvider.value(value: _alertPreferencesCubit),
            BlocProvider.value(value: _alertCubit),
          ],
          child: MaterialApp.router(
            title: 'FaceTrack',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            routerConfig: _router,
            builder: (context, child) {
              final content = _AppEffects(router: _router, child: child);
              final connection = _sessionCubit.state;
              return Stack(
                children: [
                  Positioned.fill(child: content),
                  if (_showReconnectScreen && connection != null)
                    Positioned.fill(
                      child: ReconnectingScreen(
                        address: connection.address,
                        onLogout: _logoutFromReconnectScreen,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _logoutFromReconnectScreen() {
    if (_showReconnectScreen) {
      setState(() => _showReconnectScreen = false);
    }
    _hadRealtimeConnection = false;
    unawaited(_sessionCubit.disconnect());
  }
}

/// Efeitos globais que não são renderização: iniciar o carregamento das
/// detecções + o monitoramento em segundo plano ao conectar, e abrir a tela
/// de alerta assim que um suspeito de alto risco entra na fila.
class _AppEffects extends StatelessWidget {
  const _AppEffects({required this.router, required this.child});
  final GoRouter router;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionCubit, ConnectionConfig?>(
          listener: (context, connection) {
            if (connection != null) {
              // A entrega de eventos em tempo real só deve começar quando de
              // fato há uma sessão conectada — do contrário, alertas
              // críticos, que abrem uma tela cheia não descartável, poderiam
              // chegar antes do login.
              context.read<DetectionRepository>().startRealtime();
              unawaited(context.read<DetectionsCubit>().loadRecent());
              AlertService.instance.startMonitoring(
                connectionAddress: connection.address,
              );
            } else {
              // Ao desconectar, pare de gerar/entregar alertas — inclusive
              // limpando a fila e parando qualquer vibração/notificação de
              // um alerta que porventura ainda estivesse ativo, para nunca
              // deixar o aparelho vibrando indefinidamente sem uma tela para
              // confirmar.
              context.read<DetectionRepository>().stopRealtime();
              unawaited(context.read<AlertCubit>().reset());
              unawaited(AlertService.instance.stopMonitoring());
            }
          },
        ),
        BlocListener<AlertCubit, AlertState>(
          listenWhen: (prev, curr) =>
              prev.current == null && curr.current != null,
          listener: (context, state) => router.push('/alert'),
        ),
      ],
      child: child ?? const SizedBox.shrink(),
    );
  }
}
