import 'package:flutter/painting.dart';

import '../teams/team_models.dart';

class VotingLabels {
  VotingLabels._();

  static const bestPlayer = 'best_player';
  static const bestGoalkeeper = 'best_goalkeeper';

  static String category(String code) => switch (code) {
        bestPlayer => 'Melhor jogador',
        bestGoalkeeper => 'Melhor guarda-redes',
        _ => code,
      };

  /// Porque o utilizador não pode votar (código da API).
  static String cannotVote(String? reason) => switch (reason) {
        'email_not_verified_long_enough' =>
          'Para votares sem teres participado no torneio, o teu email tem de estar verificado há mais de 1 dia.',
        'voting_closed' => 'A votação já fechou.',
        _ => 'Não podes votar nesta votação.',
      };
}

class PodiumEntry {
  const PodiumEntry({required this.place, required this.teamId, required this.name, required this.colorHex});

  final int place;
  final String teamId;
  final String name;
  final String colorHex;

  Color get color => colorFromHex(colorHex);

  factory PodiumEntry.fromJson(Map<String, dynamic> j) => PodiumEntry(
        place: (j['place'] as num?)?.toInt() ?? 0,
        teamId: j['teamId'].toString(),
        name: (j['name'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
      );
}

/// Jogador vencedor: só nome, equipa e posição.
class AwardWinner {
  const AwardWinner({
    required this.userId,
    required this.displayName,
    required this.teamName,
    required this.colorHex,
    this.position,
  });

  final String userId;
  final String displayName;
  final String teamName;
  final String colorHex;
  final String? position;

  Color get color => colorFromHex(colorHex);
  String? get positionLabel => position == null ? null : TeamLabels.position(position!);

  factory AwardWinner.fromJson(Map<String, dynamic> j) => AwardWinner(
        userId: j['userId'].toString(),
        displayName: (j['displayName'] ?? '').toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        position: j['position'] as String?,
      );
}

/// pending = empate, ainda pode haver desempate; final = decidido (um vencedor ou co-vencedores).
class Award {
  const Award({required this.status, required this.winners});

  final String status;
  final List<AwardWinner> winners;

  bool get isPending => status == 'pending';

  factory Award.fromJson(Map<String, dynamic> j) => Award(
        status: (j['status'] ?? 'final').toString(),
        winners: ((j['winners'] as List?) ?? const [])
            .map((e) => AwardWinner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class VotingCandidate {
  const VotingCandidate({
    required this.userId,
    required this.displayName,
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    this.position,
  });

  final String userId;
  final String displayName;
  final String teamId;
  final String teamName;
  final String colorHex;
  final String? position;

  Color get color => colorFromHex(colorHex);

  factory VotingCandidate.fromJson(Map<String, dynamic> j) => VotingCandidate(
        userId: j['userId'].toString(),
        displayName: (j['displayName'] ?? '').toString(),
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        position: j['position'] as String?,
      );
}

class VotingCategory {
  const VotingCategory({required this.category, required this.candidates, this.myVote});

  final String category;
  final List<VotingCandidate> candidates;

  /// userId em quem já votei (pode ser mudado).
  final String? myVote;

  factory VotingCategory.fromJson(Map<String, dynamic> j) => VotingCategory(
        category: (j['category'] ?? '').toString(),
        myVote: j['myVote']?.toString(),
        candidates: ((j['candidates'] as List?) ?? const [])
            .map((e) => VotingCandidate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Votação aberta agora (ronda 2 = desempate só entre os empatados).
class Voting {
  const Voting({
    required this.roundNumber,
    required this.closesAt,
    required this.canVote,
    required this.categories,
    this.cannotVoteReason,
  });

  final int roundNumber;
  final DateTime closesAt;
  final bool canVote;
  final String? cannotVoteReason;
  final List<VotingCategory> categories;

  bool get isTiebreak => roundNumber == 2;

  factory Voting.fromJson(Map<String, dynamic> j) => Voting(
        roundNumber: (j['roundNumber'] as num?)?.toInt() ?? 1,
        closesAt: DateTime.tryParse((j['closesAt'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        canVote: j['canVote'] == true,
        cannotVoteReason: j['cannotVoteReason'] as String?,
        categories: ((j['categories'] as List?) ?? const [])
            .map((e) => VotingCategory.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Pódio, prémios e votação de um torneio terminado.
class TournamentResults {
  const TournamentResults({this.podium = const [], this.bestPlayer, this.bestGoalkeeper, this.voting});

  final List<PodiumEntry> podium;
  final Award? bestPlayer;
  final Award? bestGoalkeeper;
  final Voting? voting;

  bool get hasAwards => bestPlayer != null || bestGoalkeeper != null;

  factory TournamentResults.fromJson(Map<String, dynamic> j) {
    Award? award(String key) =>
        j[key] is Map ? Award.fromJson(Map<String, dynamic>.from(j[key] as Map)) : null;
    return TournamentResults(
      podium: ((j['podium'] as List?) ?? const [])
          .map((e) => PodiumEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      bestPlayer: award('bestPlayer'),
      bestGoalkeeper: award('bestGoalkeeper'),
      voting: j['voting'] is Map ? Voting.fromJson(Map<String, dynamic>.from(j['voting'] as Map)) : null,
    );
  }
}
