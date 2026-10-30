import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/tournaments/tournament_models.dart';
import 'package:gamehall_torneios/widgets/skeleton.dart';

void main() {
  teamSignalTests();
  final now = DateTime(2026, 10, 26, 12);
  String? c(Duration d) => TournamentLabels.countdown(now.add(d), now: now);

  test('contagem decrescente por escalões', () {
    expect(c(const Duration(days: 5)), isNull);
    expect(c(const Duration(days: 2, hours: 20)), 'Fecha em menos de 3 dias');
    expect(c(const Duration(days: 1, hours: 20)), 'Fecha em menos de 2 dias');
    expect(c(const Duration(hours: 20)), 'Fecha em menos de 1 dia');
    expect(c(const Duration(hours: 5)), 'Fecha em menos de 12 horas');
    expect(c(const Duration(minutes: 45)), 'Fecha em menos de 1 hora');
    expect(c(const Duration(minutes: 10)), 'Fecha em menos de 30 minutos');
    expect(c(const Duration(minutes: -1)), isNull);
  });

  testWidgets('esqueleto desenha-se sem erros', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SkeletonList()))));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SkeletonCard), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox());
  });
}

void teamSignalTests() {
  test('equipa aberta (verde) vs privada/fechada (vermelho)', () {
    TeamSummary t({bool priv = false, String state = 'forming'}) => TeamSummary.fromJson(
        {'id': '1', 'name': 'A', 'colorHex': '#112233', 'isPrivate': priv, 'state': state});
    expect(t().isOpen, isTrue);
    expect(t(priv: true).isOpen, isFalse);
    expect(t(state: 'queued').isOpen, isFalse);
    expect(t(state: 'reserved').isOpen, isFalse);
    expect(TeamSummary.fromJson({'id': '1', 'name': 'A', 'confirmed': true}).state, 'confirmed');
  });
}
