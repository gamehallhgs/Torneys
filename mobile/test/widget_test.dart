import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/app.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/auth_controller.dart';
import 'package:gamehall_torneios/core/token_store.dart';

class _EmptyStore extends TokenStore {
  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveRefreshToken(String value) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('sem sessão, mostra o ecrã de boas-vindas', (tester) async {
    final controller = AuthController(api: ApiClient(), store: _EmptyStore());
    await tester.pumpWidget(GameHallApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Iniciar sessão'), findsOneWidget);
  });
}
