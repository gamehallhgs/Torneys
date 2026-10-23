import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/format.dart';
import 'package:gamehall_torneios/features/games/game_models.dart';

Map<String, dynamic> team(String id, String name, [String color = '#E53935']) =>
    {'id': id, 'name': name, 'colorHex': color};

Map<String, dynamic> gameJson({
  String id = 'g1',
  String stage = 'round',
  String? group,
  int round = 1,
  String? label = 'Quartos de final',
  int match = 1,
  String status = 'finished',
  Map<String, dynamic>? home,
  Map<String, dynamic>? away,
  int? hg = 2,
  int? ag = 1,
  int? hp,
  int? ap,
  String? when = '2026-11-05T14:30:00Z',
}) =>
    {
      'id': id,
      'stage': stage,
      'groupName': group,
      'roundNumber': round,
      'roundLabel': label,
      'matchNumber': match,
      'scheduledAt': when,
      'fieldName': 'Campo 1',
      'status': status,
      'home': home ?? team('a', 'Águias'),
      'away': away ?? team('b', 'Bravos', '#1E88E5'),
      'homeGoals': hg,
      'awayGoals': ag,
      'homePenalties': hp,
      'awayPenalties': ap,
      'highlightsCount': 1,
    };

void main() {
  group('Game', () {
    test('lê o JSON e calcula resultado e vencedor', () {
      final g = Game.fromJson(gameJson());
      expect(g.hasScore, isTrue);
      expect(g.scoreText, '2 - 1');
      expect(g.winner?.name, 'Águias');
      expect(g.penaltiesText, isNull);
      expect(g.isKnockout, isTrue);
      expect(g.scheduledAt, isNotNull);
    });

    test('empate decidido por penáltis', () {
      final g = Game.fromJson(gameJson(hg: 2, ag: 2, hp: 4, ap: 5));
      expect(g.penaltiesText, '(4-5 g.p.)');
      expect(g.winner?.name, 'Bravos');
    });

    test('empate sem penáltis não tem vencedor', () {
      expect(Game.fromJson(gameJson(stage: 'league', hg: 1, ag: 1)).winner, isNull);
    });

    test('jogo agendado ou adiado não mostra resultado', () {
      final g = Game.fromJson(gameJson(status: 'scheduled', hg: null, ag: null));
      expect(g.hasScore, isFalse);
      expect(g.scoreText, 'vs');
      expect(g.winner, isNull);
      final postponed = Game.fromJson(gameJson(status: 'postponed', hg: 3, ag: 0));
      expect(postponed.hasScore, isFalse);
    });

    test('jogo a decorrer mostra resultado mas ainda não tem vencedor', () {
      final g = Game.fromJson(gameJson(status: 'running', hg: 1, ag: 0));
      expect(g.hasScore, isTrue);
      expect(g.isLive, isTrue);
      expect(g.winner, isNull);
    });

    test('equipa por definir', () {
      final g = Game.fromJson(
          gameJson(status: 'scheduled', home: {'id': null, 'name': null, 'colorHex': null}, hg: null, ag: null));
      expect(g.home.isKnown, isFalse);
      expect(g.home.label, 'A definir');
    });

    test('título junta grupo e jornada', () {
      expect(Game.fromJson(gameJson(stage: 'group', group: 'Grupo A', label: 'Jornada 2')).title,
          'Grupo A · Jornada 2');
      expect(Game.fromJson(gameJson(stage: 'league', label: null)).title, 'Liga');
    });

    test('todos os estados e fases têm texto em português', () {
      for (final s in ['scheduled', 'running', 'finished', 'cancelled', 'postponed']) {
        expect(GameLabels.status(s), isNot(s));
      }
      for (final s in ['group', 'league', 'round', 'third_place']) {
        expect(GameLabels.stage(s), isNot(s));
      }
      for (final s in ['goal', 'assist', 'yellow_card', 'red_card']) {
        expect(GameLabels.event(s), isNot(s));
      }
    });
  });

  group('Bracket', () {
    test('agrupa por ronda, ordena e separa o 3.º lugar', () {
      final games = [
        Game.fromJson(gameJson(id: 'f', round: 3, label: 'Final', match: 8)),
        Game.fromJson(gameJson(id: 'q2', round: 1, match: 2)),
        Game.fromJson(gameJson(id: 'q1', round: 1, match: 1)),
        Game.fromJson(gameJson(id: 's1', round: 2, label: 'Meias-finais', match: 5)),
        Game.fromJson(gameJson(id: 't', stage: 'third_place', round: 3, label: '3.º e 4.º lugar', match: 7)),
        Game.fromJson(gameJson(id: 'l', stage: 'league', label: 'Jornada 1')),
      ];
      final b = Bracket.fromGames(games);
      expect(b.rounds.map((r) => r.label).toList(), ['Quartos de final', 'Meias-finais', 'Final']);
      expect(b.rounds.first.games.map((g) => g.id).toList(), ['q1', 'q2']);
      expect(b.thirdPlace.single.id, 't');
      expect(b.isEmpty, isFalse);
    });

    test('sem eliminatórias fica vazio', () {
      expect(Bracket.fromGames([Game.fromJson(gameJson(stage: 'league'))]).isEmpty, isTrue);
    });
  });

  test('GameDetail lê eventos e vídeos', () {
    final d = GameDetail.fromJson({
      'game': gameJson(),
      'tournamentId': 't1',
      'tournamentName': 'Taça',
      'events': [
        {'id': 'e1', 'teamId': 'a', 'playerName': 'Rui', 'type': 'goal', 'minute': 12},
        {'id': 'e2', 'teamId': 'b', 'playerName': 'Tiago', 'type': 'yellow_card', 'minute': null},
      ],
      'highlights': [
        {'id': 'h1', 'url': 'https://exemplo.pt/v.mp4', 'title': null, 'durationSeconds': 20},
      ],
    });
    expect(d.tournamentName, 'Taça');
    expect(d.events, hasLength(2));
    expect(d.events.first.minute, 12);
    expect(d.events.last.minute, isNull);
    expect(d.highlights.single.durationSeconds, 20);
  });

  test('Standings e estatísticas lêem o JSON', () {
    Map<String, dynamic> row(int pos, String name, int pts, int gd) => {
          'position': pos, 'teamId': 't$pos', 'name': name, 'colorHex': '#E53935',
          'played': 2, 'won': 1, 'drawn': 0, 'lost': 1, 'goalsFor': 3, 'goalsAgainst': 2,
          'goalDifference': gd, 'points': pts, 'yellowCards': 1, 'redCards': 0,
        };
    final s = Standings.fromJson({
      'tiebreakers': ['points', 'goal_difference'],
      'groups': [
        {'name': null, 'rows': [row(1, 'A', 6, 3), row(2, 'B', 3, -2), row(3, 'C', 0, 0)]},
      ],
    });
    expect(s.groups.single.name, isNull);
    expect(s.groups.single.rows.map((r) => r.name).toList(), ['A', 'B', 'C']);
    expect(s.groups.single.rows[0].goalDifferenceText, '+3');
    expect(s.groups.single.rows[1].goalDifferenceText, '-2');
    expect(s.groups.single.rows[2].goalDifferenceText, '0');

    final stats = TournamentStats.fromJson({
      'scorers': [
        {'playerName': 'Rui', 'teamId': 'a', 'teamName': 'Águias', 'colorHex': '#E53935', 'total': 4},
      ],
      'assists': [],
      'yellowCards': [],
      'redCards': [],
    });
    expect(stats.isEmpty, isFalse);
    expect(stats.scorers.single.total, 4);
    expect(TournamentStats.fromJson({}).isEmpty, isTrue);
  });

  test('Fmt.dateTime e Fmt.time', () {
    final d = DateTime(2026, 11, 7, 9, 5); // sábado
    expect(Fmt.time(d), '09:05');
    expect(Fmt.dateTime(d), 'sáb, 7 nov · 09:05');
  });
}
