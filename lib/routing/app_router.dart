import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/cubit/session_cubit.dart';
import '../features/auth/view/login_screen.dart';
import '../features/detections/view/detection_detail_screen.dart';
import '../features/detections/view/detection_history_screen.dart';
import '../features/detections/view/detections_list_screen.dart';
import '../features/alert/view/alert_screen.dart';
import '../features/settings/view/alert_preferences_screen.dart';

/// Faz o [GoRouter] reavaliar `redirect` sempre que a stream muda de valor —
/// aqui, sempre que [SessionCubit] conecta/desconecta.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildAppRouter({required SessionCubit sessionCubit}) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(sessionCubit.stream),
    redirect: (context, state) {
      final connected = sessionCubit.state != null;
      final goingToLogin = state.matchedLocation == '/login';
      if (!connected && !goingToLogin) return '/login';
      if (connected && goingToLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DetectionsListScreen(),
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const DetectionHistoryScreen(),
      ),
      GoRoute(
        path: '/detection/:id',
        builder: (context, state) =>
            DetectionDetailScreen(detectionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/alert', builder: (context, state) => const AlertScreen()),
      GoRoute(
        path: '/settings/alerts',
        builder: (context, state) => const AlertPreferencesScreen(),
      ),
    ],
  );
}
