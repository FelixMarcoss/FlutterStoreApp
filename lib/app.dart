import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/alert/alert_service.dart';
import 'features/alert/cubit/alert_cubit.dart';
import 'features/auth/cubit/session_cubit.dart';
import 'features/auth/data/models/connection_config.dart';
import 'features/auth/data/repositories/connection_repository.dart';
import 'features/auth/data/repositories/mock_connection_repository.dart';
import 'features/detections/cubit/detections_cubit.dart';
import 'features/detections/data/repositories/detection_repository.dart';
import 'features/detections/data/repositories/mock_detection_repository.dart';
import 'routing/app_router.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final ConnectionRepository _connectionRepository;
  late final DetectionRepository _detectionRepository;
  late final SessionCubit _sessionCubit;
  late final DetectionsCubit _detectionsCubit;
  late final AlertCubit _alertCubit;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Trocar pelas implementações reais (HTTP/WebSocket) quando o software
    // principal expuser uma API local — nada mais no app precisa mudar.
    _connectionRepository = MockConnectionRepository();
    _detectionRepository = MockDetectionRepository();

    _sessionCubit = SessionCubit(connectionRepository: _connectionRepository);
    _detectionsCubit = DetectionsCubit(detectionRepository: _detectionRepository);
    _alertCubit = AlertCubit(
      detectionRepository: _detectionRepository,
      detectionsCubit: _detectionsCubit,
    );
    _router = buildAppRouter(sessionCubit: _sessionCubit);
  }

  @override
  void dispose() {
    _sessionCubit.close();
    _detectionsCubit.close();
    _alertCubit.close();
    _detectionRepository.dispose();
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
            BlocProvider.value(value: _alertCubit),
          ],
          child: MaterialApp.router(
            title: 'Sentinela',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            routerConfig: _router,
            builder: (context, child) => _AppEffects(child: child),
          ),
        ),
      ),
    );
  }
}

/// Efeitos globais que não são renderização: iniciar o carregamento das
/// detecções + o monitoramento em segundo plano ao conectar, e abrir a tela
/// de alerta assim que um "ladrão conhecido" entra na fila.
class _AppEffects extends StatelessWidget {
  const _AppEffects({required this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionCubit, ConnectionConfig?>(
          listener: (context, connection) {
            if (connection != null) {
              // A entrega de eventos em tempo real só deve começar quando de
              // fato há uma sessão conectada — do contrário, alertas mockados
              // (inclusive de "ladrão conhecido", que abrem a tela cheia e
              // não descartável) poderiam chegar antes do login.
              context.read<DetectionRepository>().startRealtime();
              context.read<DetectionsCubit>().fetchInitial();
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
              context.read<AlertCubit>().reset();
              AlertService.instance.stopMonitoring();
            }
          },
        ),
        BlocListener<AlertCubit, AlertState>(
          listenWhen: (prev, curr) => prev.current == null && curr.current != null,
          listener: (context, state) => GoRouter.of(context).push('/alert'),
        ),
      ],
      child: child ?? const SizedBox.shrink(),
    );
  }
}
