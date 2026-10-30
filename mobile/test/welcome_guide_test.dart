import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/models.dart';
import 'package:gamehall_torneios/features/onboarding/welcome_guide_screen.dart';

void main() {
  test('o guia tem 5 ecrãs', () => expect(guideSteps.length, 5));

  test('onboardingSeen: por defeito visto; false vem do servidor', () {
    expect(AppUser.fromJson({'id': '1'}).onboardingSeen, isTrue);
    expect(AppUser.fromJson({'id': '1', 'onboardingSeen': false}).onboardingSeen, isFalse);
    expect(AppUser.fromJson({'id': '1', 'onboardingSeen': false}).copyWith(onboardingSeen: true).onboardingSeen, isTrue);
  });

  testWidgets('Seguinte avança e Começar fecha', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const WelcomeGuideScreen())),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Encontra torneios'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Seguinte'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Fica a par'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });
}
