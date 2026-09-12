import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sentinela_app/app.dart';

void main() {
  testWidgets('App abre na tela de login quando não há sessão ativa', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.text('Sentinela'), findsOneWidget);
    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Conectar'), findsOneWidget);
  });
}
