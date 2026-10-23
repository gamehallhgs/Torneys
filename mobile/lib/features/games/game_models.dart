import 'package:flutter/painting.dart';

import '../teams/team_models.dart';

/// Textos em português dos códigos devolvidos pela API (jogos).
class GameLabels {
  GameLabels._();

  static String status(String code) => switch (code) {
        'scheduled' => 'Agendado',
        'running' => 'A decorrer',
        'finished' => 'Terminado',
        'cancelled' => 'Cancelado',
        'postponed' => 'Adiado',
        _ => code,
      };

  static String stage(String code) => switch (code) {
        'group' => 'Fase de grupos',
        'league' => 'Liga',
        'round' => 'Eliminatórias',
        'third_place' => '3.º e 4.º lugar',
        _ => code,
      };

  static String event(String code) => switch (code) {
        'goal' => 'Golo',
        'assist' => 'Assistência',
        'yellow_card' => 'Cartão amarelo',
        'red_card' => 'Cartão vermelho',
        _ => code,
      };
}

class GameTeam {
  const GameTeam({this.id, this.name, this.colorHex});

  final String? id;
  final String? name;
  final String? colorHex;

  bool get isKnown => id != null;
  String get label => name ?? 'A definir';
  Color get color => colorHex == null ? const Color(0xFF6F6F6F) : colorFromHex(colorHex!);

  factory GameTeam.fromJson(Map<String, dynamic>? j) => GameTeam(
        id: j?['id']?.toString(),
        name: j?['name'] as String?,
        colorHex: j?['colorHex'] as String?,
      );
}

class Game {
  const Game({
    required this.id,
    required this.stage,
    required this.groupName,
    required this.roundNumber,
    required this.roundLabel,
    required this.matchNumber,
    required this.scheduledAt,
    required this.fieldName,
    required this.status,
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.homePenalties,
    required this.awayPenalties,
    required this.highlightsCount,
  });

  final String id;
  final String stage;
  final String? groupName;
  final int roundNumber;
  final String? roundLabel;
  final int matchNumber;
  final DateTime? scheduledAt;
  final String? fieldName;
  final String status;
  final GameTeam home;
  final GameTeam away;
  final int? homeGoals;
  final int? awayGoals;
  final int? homePenalties;
  final int? awayPenalties;
  final int highlightsCount;

  bool get isKnockout => stage == 'round' || stage == 'third_place';
  bool get isLive => status == 'running';
  bool get isFinished => status == 'finished';

  /// Só mostramos resultado em jogos a decorrer ou terminados.
  bool get hasScore =>
      homeGoals != null && awayGoals != null && (status == 'finished' || status == 'running');

  bool get hasPenalties => hasScore && homePenalties != null && awayPenalties != null;

  /// "2 - 1"
  String get scoreText => hasScore ? '$homeGoals - $awayGoals' : 'vs';

  /// "(5-4 g.p.)" quando houve desempate por penáltis.
  String? get penaltiesText => hasPenalties ? '($homePenalties-$awayPenalties g.p.)' : null;

  /// Quem venceu (tendo em conta os penáltis). Null se ainda não há vencedor.
  GameTeam? get winner {
    if (!isFinished || !hasScore) {
      return null;
    }
    if (homeGoals! > awayGoals!) {
      return home;
    }
    if (awayGoals! > homeGoals!) {
      return away;
    }
    if (hasPenalties) {
      return homePenalties! > awayPenalties! ? home : away;
    }
    return null;
  }

  /// Título curto do jogo: "Jornada 2", "Grupo A · Jornada 1", "Final".
  String get title {
    final parts = <String>[
      if (groupName != null && groupName!.isNotEmpty) groupName!,
      roundLabel ?? GameLabels.stage(stage),
    ];
    return parts.join(' · ');
  }

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'].toString(),
        stage: (j['stage'] ?? '').toString(),
        groupName: j['groupName'] as String?,
        roundNumber: (j['roundNumber'] as num?)?.toInt() ?? 1,
        roundLabel: j['roundLabel'] as String?,
        matchNumber: (j['matchNumber'] as num?)?.toInt() ?? 1,
        scheduledAt: j['scheduledAt'] == null
            ? null
            : DateTime.parse(j['scheduledAt'].toString()).toLocal(),
        fieldName: j['fieldName'] as String?,
        status: (j['status'] ?? '').toString(),
        home: GameTeam.fromJson(j['home'] is Map ? Map<String, dynamic>.from(j['home'] as Map) : null),
        away: GameTeam.fromJson(j['away'] is Map ? Map<String, dynamic>.from(j['away'] as Map) : null),
        homeGoals: (j['homeGoals'] as num?)?.toInt(),
        awayGoals: (j['awayGoals'] as num?)?.toInt(),
        homePenalties: (j['homePenalties'] as num?)?.toInt(),
        awayPenalties: (j['awayPenalties'] as num?)?.toInt(),
        highlightsCount: (j['highlightsCount'] as num?)?.toInt() ?? 0,
      );
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.teamId,
    required this.playerName,
    required this.type,
    required this.minute,
  });

  final String id;
  final String teamId;
  final String playerName;
  final String type;
  final int? minute;

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
        id: j['id'].toString(),
        teamId: j['teamId'].toString(),
        playerName: (j['playerName'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        minute: (j['minute'] as num?)?.toInt(),
      );
}

class Highlight {
  const Highlight({
    required this.id,
    required this.url,
    required this.title,
    required this.durationSeconds,
  });

  final String id;
  final String url;
  final String? title;
  final int durationSeconds;

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        id: j['id'].toString(),
        url: (j['url'] ?? '').toString(),
        title: j['title'] as String?,
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      );
}

class GameDetail {
  const GameDetail({
    required this.game,
    required this.tournamentName,
    required this.events,
    required this.highlights,
  });

  final Game game;
  final String tournamentName;
  final List<GameEvent> events;
  final List<Highlight> highlights;

  factory GameDetail.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String key) => ((j[key] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return GameDetail(
      game: Game.fromJson(Map<String, dynamic>.from(j['game'] as Map)),
      tournamentName: (j['tournamentName'] ?? '').toString(),
      events: list('events').map(GameEvent.fromJson).toList(),
      highlights: list('highlights').map(Highlight.fromJson).toList(),
    );
  }
}

class StandingRow {
  const StandingRow({
    required this.position,
    required this.teamId,
    required this.name,
    required this.colorHex,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    required this.yellowCards,
    required this.redCards,
  });

  final int position;
  final String teamId;
  final String name;
  final String colorHex;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
  final int yellowCards;
  final int redCards;

  Color get color => colorFromHex(colorHex);

  /// "+3", "0", "-2"
  String get goalDifferenceText => goalDifference > 0 ? '+$goalDifference' : '$goalDifference';

  factory StandingRow.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return StandingRow(
      position: n('position'),
      teamId: j['teamId'].toString(),
      name: (j['name'] ?? '').toString(),
      colorHex: (j['colorHex'] ?? '#888888').toString(),
      played: n('played'),
      won: n('won'),
      drawn: n('drawn'),
      lost: n('lost'),
      goalsFor: n('goalsFor'),
      goalsAgainst: n('goalsAgainst'),
      goalDifference: n('goalDifference'),
      points: n('points'),
      yellowCards: n('yellowCards'),
      redCards: n('redCards'),
    );
  }
}

class StandingsGroup {
  const StandingsGroup({required this.name, required this.rows});

  final String? name;
  final List<StandingRow> rows;
}

class Standings {
  const Standings({required this.tiebreakers, required this.groups});

  final List<String> tiebreakers;
  final List<StandingsGroup> groups;

  factory Standings.fromJson(Map<String, dynamic> j) => Standings(
        tiebreakers: ((j['tiebreakers'] as List?) ?? const []).map((e) => e.toString()).toList(),
        groups: ((j['groups'] as List?) ?? const []).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return StandingsGroup(
            name: m['name'] as String?,
            rows: ((m['rows'] as List?) ?? const [])
                .map((r) => StandingRow.fromJson(Map<String, dynamic>.from(r as Map)))
                .toList(),
          );
        }).toList(),
      );
}

class StatLine {
  const StatLine({
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    required this.total,
  });

  final String playerName;
  final String teamId;
  final String teamName;
  final String colorHex;
  final int total;

  Color get color => colorFromHex(colorHex);

  factory StatLine.fromJson(Map<String, dynamic> j) => StatLine(
        playerName: (j['playerName'] ?? '').toString(),
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

class TournamentStats {
  const TournamentStats({
    required this.scorers,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
  });

  final List<StatLine> scorers;
  final List<StatLine> assists;
  final List<StatLine> yellowCards;
  final List<StatLine> redCards;

  bool get isEmpty =>
      scorers.isEmpty && assists.isEmpty && yellowCards.isEmpty && redCards.isEmpty;

  factory TournamentStats.fromJson(Map<String, dynamic> j) {
    List<StatLine> lines(String key) => ((j[key] as List?) ?? const [])
        .map((e) => StatLine.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return TournamentStats(
      scorers: lines('scorers'),
      assists: lines('assists'),
      yellowCards: lines('yellowCards'),
      redCards: lines('redCards'),
    );
  }
}

/// Ronda de eliminatórias para desenhar o quadro.
class BracketRound {
  const BracketRound({required this.number, required this.label, required this.games});

  final int number;
  final String label;
  final List<Game> games;
}

/// Agrupa os jogos de eliminatórias por ronda (a final fica na última coluna).
/// O jogo do 3.º/4.º lugar sai à parte, em [thirdPlace].
class Bracket {
  const Bracket({required this.rounds, required this.thirdPlace});

  final List<BracketRound> rounds;
  final List<Game> thirdPlace;

  bool get isEmpty => rounds.isEmpty && thirdPlace.isEmpty;

  factory Bracket.fromGames(List<Game> games) {
    final knockout = games.where((g) => g.stage == 'round').toList();
    final byRound = <int, List<Game>>{};
    for (final g in knockout) {
      byRound.putIfAbsent(g.roundNumber, () => []).add(g);
    }
    final numbers = byRound.keys.toList()..sort();
    final rounds = [
      for (final n in numbers)
        BracketRound(
          number: n,
          label: byRound[n]!.first.roundLabel ?? 'Ronda $n',
          games: (byRound[n]!..sort((a, b) => a.matchNumber.compareTo(b.matchNumber))),
        ),
    ];
    final third = games.where((g) => g.stage == 'third_place').toList()
      ..sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
    return Bracket(rounds: rounds, thirdPlace: third);
  }
}
