import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_session.dart';
import 'features/alert/alert_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _FaceTrackBootstrap());
}

class _FaceTrackBootstrap extends StatefulWidget {
  const _FaceTrackBootstrap();

  @override
  State<_FaceTrackBootstrap> createState() => _FaceTrackBootstrapState();
}

class _FaceTrackBootstrapState extends State<_FaceTrackBootstrap> {
  late Future<ApiSession> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<ApiSession> _initialize() async {
    try {
      await AlertService.instance.init().timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Notificações podem ser configuradas depois. Elas nunca devem impedir
      // que a interface principal seja exibida.
    }
    return ApiSession.forLocalFaceTrack();
  }

  void _retry() {
    setState(() => _initialization = _initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiSession>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasData) return App(apiSession: snapshot.data!);
        return MaterialApp(
          title: 'FaceTrack',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            backgroundColor: const Color(0xFF0B1016),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: snapshot.hasError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.security_outlined,
                              color: Color(0xFFEF4444),
                              size: 52,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Não foi possível iniciar o aplicativo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Feche o aplicativo e tente novamente.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFFA9B4C0)),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _retry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text(
                              'Iniciando FaceTrack…',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
