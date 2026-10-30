import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/games/game_models.dart';

void main() {
  test('plantel do jogo: titulares por lugar e suplentes', () {
    final squad = Squad.fromJson({
      'formation': '2-3-1',
      'players': [
        {'displayName': 'Rui', 'position': 'GK', 'slot': 0, 'isStarter': true},
        {'displayName': 'Tiago', 'slot': null, 'isStarter': false},
      ],
    })!;
    expect(squad.atSlot(0)!.displayName, 'Rui');
    expect(squad.atSlot(1), isNull);
    expect(squad.bench.single.displayName, 'Tiago');
    expect(Squad.fromJson(null), isNull);
  });

  test('sem plantel formal vem como lista de membros', () {
    final squad = Squad.fromJson({
      'formation': null,
      'isFormal': false,
      'players': [
        {'displayName': 'Guarda', 'position': 'GK', 'slot': null, 'isStarter': false},
        {'displayName': 'Ponta', 'position': 'ST', 'slot': null, 'isStarter': false},
      ],
    })!;
    expect(squad.isFormal, isFalse);
    expect(squad.players.first.displayName, 'Guarda');
  });
}
