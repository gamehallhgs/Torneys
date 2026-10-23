import 'package:flutter/painting.dart';

import '../../core/format.dart';

/// Textos em português dos códigos devolvidos pela API.
class TournamentLabels {
  TournamentLabels._();

  static String sport(String code) => switch (code) {
        'football7' => 'Futebol 7',
        'football9' => 'Futebol 9',
        'football11' => 'Futebol 11',
        'futsal' => 'Futsal',
        _ => code,
      };

  static String format(String code) => switch (code) {
        'single_elimination' => 'Eliminatórias',
        'double_elimination' => 'Dupla eliminação',
        'groups_knockout' => 'Fase de grupos + eliminatórias',
        'league' => 'Liga',
        _ => code,
      };

  static String status(String code) => switch (code) {
        'registration_open' => 'Inscrições abertas',
        'registration_closed' => 'Inscrições fechadas',
        'ongoing' => 'A decorrer',
        'finished' => 'Terminado',
        _ => code,
      };

  static String tiebreaker(String code) => switch (code) {
        'points' => 'Pontos',
        'head_to_head' => 'Confronto direto',
        'goal_difference' => 'Diferença de golos',
        'goals_for' => 'Golos marcados',
        'goals_against' => 'Golos sofridos',
        'wins' => 'Vitórias',
        'fair_play' => 'Fair play (cartões amarelos e vermelhos)',
        'draw' => 'Sorteio',
        'penalties' => 'Grandes penalidades',
        _ => code,
      };

  /// "3/8 equipas confirmadas · 5 em formação"
  /// Valor do menu de modalidades para "todas". Não pode ser null: o PopupMenuButton não chama
  /// onSelected para itens com valor null (era o bug de não conseguir voltar a "Todas as modalidades").
  static const allSports = 'all';

  /// Valor do menu -> filtro da API (null = sem filtro).
  static String? sportFilter(String menuValue) => menuValue == allSports ? null : menuValue;

  static String teamsLine(int confirmed, int max, int inFormation) =>
      '$confirmed/$max equipas confirmadas${inFormation > 0 ? ' · $inFormation em formação' : ''}';

  /// Motivo (código da API) -> mensagem para o utilizador.
  static String ineligible(String? reason, {required int minAge, int? maxAge}) =>
      switch (reason) {
        'registration_closed' => 'As inscrições não estão abertas.',
        'age_too_young' => 'Este torneio é para participantes com $minAge anos ou mais.',
        'age_too_old' => 'Este torneio é para participantes até $maxAge anos.',
        'tournament_full' => 'O torneio já tem todas as equipas confirmadas.',
        _ => 'Não podes criar equipa neste torneio.',
      };
}

class TournamentSummary {
  const TournamentSummary({
    required this.id,
    required this.name,
    required this.organizerName,
    required this.sport,
    required this.format,
    required this.status,
    required this.startsOn,
    required this.endsOn,
    required this.locationName,
    required this.entryFeeCents,
    required this.teamsRegistered,
    required this.maxTeams,
    required this.minAge,
    required this.maxAge,
    required this.ageLabel,
    required this.registrationClosesAt,
    required this.teamsConfirmed,
    required this.isFull,
    this.district,
    this.municipality,
  });

  final String id;
  final String name;
  final String organizerName;
  final String sport;
  final String format;
  final String status;
  final DateTime startsOn;
  final DateTime endsOn;
  final String locationName;
  final String? district;
  final String? municipality;
  final int entryFeeCents;
  final int teamsRegistered;

  /// Equipas confirmadas (completas e pagas): são as que ocupam vaga.
  final int teamsConfirmed;

  /// Todas as vagas estão ocupadas por equipas confirmadas.
  final bool isFull;
  final int maxTeams;
  final int minAge;
  final int? maxAge;
  final String ageLabel;
  final DateTime registrationClosesAt;

  /// "Pavilhão X · Cascais, Lisboa" (concelho e distrito só se existirem).
  String get placeLine {
    final area = [municipality, district].whereType<String>().join(', ');
    return area.isEmpty ? locationName : '$locationName · $area';
  }

  int get spotsLeft => (maxTeams - teamsConfirmed).clamp(0, maxTeams);

  /// Equipas criadas que ainda não estão confirmadas.
  int get teamsInFormation => (teamsRegistered - teamsConfirmed).clamp(0, teamsRegistered);

  /// Etiqueta laranja "Cheio": só faz sentido enquanto as inscrições estão abertas.
  bool get showFullFlag => status == 'registration_open' && isFull;

  factory TournamentSummary.fromJson(Map<String, dynamic> j) {
    final confirmed = (j['teamsConfirmed'] as num?)?.toInt() ?? 0;
    final max = (j['maxTeams'] as num?)?.toInt() ?? 0;
    return TournamentSummary(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        organizerName: (j['organizerName'] ?? '').toString(),
        sport: (j['sport'] ?? '').toString(),
        format: (j['format'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        startsOn: Fmt.parseDate(j['startsOn'].toString()),
        endsOn: Fmt.parseDate(j['endsOn'].toString()),
        locationName: (j['locationName'] ?? '').toString(),
        district: j['district'] as String?,
        municipality: j['municipality'] as String?,
        entryFeeCents: (j['entryFeeCents'] as num?)?.toInt() ?? 0,
        teamsRegistered: (j['teamsRegistered'] as num?)?.toInt() ?? 0,
        maxTeams: (j['maxTeams'] as num?)?.toInt() ?? 0,
        minAge: (j['minAge'] as num?)?.toInt() ?? 13,
        maxAge: (j['maxAge'] as num?)?.toInt(),
        ageLabel: (j['ageLabel'] ?? '').toString(),
        registrationClosesAt: DateTime.parse(j['registrationClosesAt'].toString()).toLocal(),
        teamsConfirmed: confirmed,
        isFull: j['isFull'] is bool ? j['isFull'] as bool : (max > 0 && confirmed >= max),
      );
  }
}

class TournamentPage {
  const TournamentPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<TournamentSummary> items;
  final int total;
  final int page;
  final int pageSize;

  factory TournamentPage.fromJson(Map<String, dynamic> j) {
    final list = (j['items'] as List?) ?? const [];
    return TournamentPage(
      items: list
          .map((e) => TournamentSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (j['total'] as num?)?.toInt() ?? 0,
      page: (j['page'] as num?)?.toInt() ?? 1,
      pageSize: (j['pageSize'] as num?)?.toInt() ?? 20,
    );
  }
}

class TeamSummary {
  const TeamSummary({
    required this.id,
    required this.name,
    required this.colorHex,
    this.confirmed = false,
  });

  final String id;
  final String name;
  final String colorHex;
  final bool confirmed;

  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    return Color(0xFF000000 | (value ?? 0x888888));
  }

  factory TeamSummary.fromJson(Map<String, dynamic> j) => TeamSummary(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        confirmed: j['confirmed'] == true,
      );
}

/// Resumo da equipa do utilizador num torneio.
class MyTeamBrief {
  const MyTeamBrief({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.isHost,
    required this.membersCount,
    this.confirmed = false,
  });

  final String id;
  final String name;
  final String colorHex;
  final bool confirmed;
  final bool isHost;
  final int membersCount;

  Color get color {
    final value = int.tryParse(colorHex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x888888));
  }

  factory MyTeamBrief.fromJson(Map<String, dynamic> j) => MyTeamBrief(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        isHost: j['isHost'] == true,
        membersCount: (j['membersCount'] as num?)?.toInt() ?? 0,
        confirmed: j['confirmed'] == true,
      );
}

class TournamentDetail {
  const TournamentDetail({
    required this.summary,
    required this.description,
    required this.hasThirdPlace,
    required this.tiebreakers,
    required this.locationAddress,
    required this.minPlayersPerTeam,
    required this.maxPlayersPerTeam,
    required this.teams,
    required this.canCreateTeam,
    required this.ineligibleReason,
    required this.myTeamId,
    required this.myTeam,
  });

  final TournamentSummary summary;
  final String? description;
  final bool hasThirdPlace;
  final List<String> tiebreakers;
  final String? locationAddress;
  final int minPlayersPerTeam;
  final int maxPlayersPerTeam;
  final List<TeamSummary> teams;
  final bool canCreateTeam;
  final String? ineligibleReason;

  /// Equipa do utilizador neste torneio (se estiver numa).
  final String? myTeamId;

  /// Resumo da equipa do utilizador (nome, nº de membros), se estiver numa.
  final MyTeamBrief? myTeam;

  factory TournamentDetail.fromJson(Map<String, dynamic> j) {
    final eligibility = Map<String, dynamic>.from((j['eligibility'] as Map?) ?? const {});
    return TournamentDetail(
      summary: TournamentSummary.fromJson(Map<String, dynamic>.from(j['summary'] as Map)),
      description: j['description'] as String?,
      hasThirdPlace: j['hasThirdPlace'] == true,
      tiebreakers: ((j['tiebreakers'] as List?) ?? const []).map((e) => e.toString()).toList(),
      locationAddress: j['locationAddress'] as String?,
      minPlayersPerTeam: (j['minPlayersPerTeam'] as num?)?.toInt() ?? 0,
      maxPlayersPerTeam: (j['maxPlayersPerTeam'] as num?)?.toInt() ?? 0,
      teams: ((j['teams'] as List?) ?? const [])
          .map((e) => TeamSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      canCreateTeam: eligibility['canCreateTeam'] == true,
      ineligibleReason: eligibility['reason'] as String?,
      myTeamId: j['myTeamId']?.toString(),
      myTeam: j['myTeam'] is Map
          ? MyTeamBrief.fromJson(Map<String, dynamic>.from(j['myTeam'] as Map))
          : null,
    );
  }
}
