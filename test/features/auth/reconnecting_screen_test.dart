import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela_app/core/theme/app_theme.dart';
import 'package:sentinela_app/features/auth/view/reconnecting_screen.dart';

void main() {
  testWidgets('mostra endereço, animação e permite logout explícito', (
    tester,
  ) async {
    var logoutRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ReconnectingScreen(
          address: '192.168.10.1:8443',
          onLogout: () => logoutRequested = true,
        ),
      ),
    );

    expect(find.byKey(const Key('reconnecting_screen')), findsOneWidget);
    expect(find.byKey(const Key('reconnecting_progress')), findsOneWidget);
    expect(find.text('Reconectando...'), findsOneWidget);
    expect(find.text('192.168.10.1:8443'), findsOneWidget);
    expect(find.text('SAIR E FAZER LOGOUT'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reconnecting_logout_button')));
    await tester.pump();

    expect(logoutRequested, isTrue);
    expect(tester.takeException(), isNull);
  });
}
