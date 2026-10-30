import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/teams/lineup_screen.dart';
import 'package:gamehall_torneios/features/teams/team_models.dart';

void main() {
  test('layout: guarda-redes + linhas da formação', () {
    final spots = Lineup.layout('4-4-2');
    expect(spots.length, 11);
    expect(spots.first.y, 0);
    expect(spots[1].y, lessThan(spots[5].y));
    expect(spots[5].y, lessThan(spots[9].y));
    expect(spots[1].x, lessThan(spots[2].x));
    expect(Lineup.layout('2-3-1').length, 7);
    expect(Lineup.layout('lixo'), isEmpty);
  });

  test('lê a formação e o lugar dos membros', () {
    final lineup = Lineup.fromJson({
      'formation': '2-3-1',
      'formations': ['2-3-1', '3-2-1'],
      'slotCount': 7,
    });
    expect(lineup.formations.length, 2);
    final m = TeamMember.fromJson({'userId': 'u', 'displayName': 'A', 'slot': 3});
    expect(m.slot, 3);
    expect(TeamMember.fromJson({'userId': 'u', 'displayName': 'A'}).slot, isNull);
  });

  testWidgets('o campo mostra um lugar por jogador e os nomes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: Pitch(
            formation: '2-3-1',
            color: Colors.red,
            nameAt: (slot) => slot == 0 ? 'Rui' : null,
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('spot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('spot-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('spot-7')), findsNothing);
    expect(find.text('Rui'), findsOneWidget);
  });
}
