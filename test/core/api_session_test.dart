import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela_app/core/network/api_session.dart';

void main() {
  test('cria uma sessão inativa antes da autenticação', () {
    final session = ApiSession();

    expect(session.isAuthenticated, isFalse);

    session.dispose();
  });
}
