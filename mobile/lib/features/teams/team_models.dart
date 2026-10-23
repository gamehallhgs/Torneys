import 'package:flutter/painting.dart';

/// Posições estilo jogos FIFA (código da API -> nome em português).
class TeamLabels {
  TeamLabels._();

  static const List<String> positionCodes = [
    'GK', 'RB', 'CB', 'LB', 'RWB', 'LWB', 'CDM', 'CM',
    'CAM', 'RM', 'LM', 'RW', 'LW', 'CF', 'ST',
  ];

  static String position(String code) => switch (code) {
        'GK' => 'Guarda-redes',
        'RB' => 'Lateral direito',
        'CB' => 'Defesa central',
        'LB' => 'Lateral esquerdo',
        'RWB' => 'Ala direito',
        'LWB' => 'Ala esquerdo',
        'CDM' => 'Médio defensivo',
        'CM' => 'Médio centro',
        'CAM' => 'Médio ofensivo',
        'RM' => 'Médio direito',
        'LM' => 'Médio esquerdo',
        'RW' => 'Extremo direito',
        'LW' => 'Extremo esquerdo',
        'CF' => 'Segundo avançado',
        'ST' => 'Avançado',
        _ => code,
      };

  /// Cores sugeridas para as equipas (a API garante que são únicas por torneio).
  static const List<String> palette = [
    '#E53935', '#D81B60', '#8E24AA', '#5E35B1', '#1E88E5', '#00ACC1',
    '#00897B', '#43A047', '#C0CA33', '#FDD835', '#FB8C00', '#6D4C41',
    '#FFFFFF', '#212121', '#78909C', '#FF4081',
  ];

  static String joinBlocked(String? reason) => switch (reason) {
        'team_not_joinable' => 'Esta equipa já não aceita pedidos.',
        'already_member' => 'Já fazes parte desta equipa.',
        'registration_closed' => 'As inscrições não estão abertas.',
        'already_in_team' => 'Já estás noutra equipa deste torneio.',
        'age_too_young' => 'Não tens a idade mínima para este torneio.',
        'age_too_old' => 'Ultrapassas a idade máxima deste torneio.',
        'team_full' => 'A equipa está completa.',
        'team_confirmed' => 'A equipa já está confirmada e fechada.',
        'lobby_closed' => 'O líder fechou este lobby: só se entra por convite.',
        'request_pending' => 'O teu pedido está a aguardar resposta do líder.',
        _ => 'Não podes entrar nesta equipa.',
      };
}

Color colorFromHex(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | (value ?? 0x888888));
}

class TeamMember {
  const TeamMember({
    required this.userId,
    required this.displayName,
    required this.position,
    required this.isHost,
    required this.isMe,
    this.paid,
  });

  final String userId;
  final String displayName;
  final String? position;
  final bool isHost;
  final bool isMe;
  /// null = não sabes (só os membros da equipa veem os pagamentos).
  final bool? paid;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        userId: j['userId'].toString(),
        displayName: (j['displayName'] ?? '').toString(),
        position: j['position'] as String?,
        isHost: j['isHost'] == true,
        isMe: j['isMe'] == true,
        paid: j['paid'] as bool?,
      );
}

/// Pedido para entrar ou convite pendente (vistos pelo líder).
class PendingItem {
  const PendingItem({
    required this.id,
    required this.userId,
    required this.displayName,
  });

  final String id;
  final String userId;
  final String displayName;

  factory PendingItem.fromJson(Map<String, dynamic> j) => PendingItem(
        id: j['id'].toString(),
        userId: j['userId'].toString(),
        displayName: (j['displayName'] ?? '').toString(),
      );
}

class TeamLobby {
  const TeamLobby({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.tournamentId,
    required this.tournamentName,
    required this.tournamentStatus,
    required this.minPlayers,
    required this.maxPlayers,
    required this.membersCount,
    required this.members,
    required this.missingPositions,
    required this.requests,
    required this.invites,
    required this.isMember,
    required this.isHost,
    required this.pendingRequestId,
    required this.pendingInviteId,
    required this.canRequestToJoin,
    required this.joinBlockedReason,
    this.confirmed = false,
    this.closedToRequests = false,
    this.membersCanInvite = false,
    this.canInvite = false,
    this.teamsConfirmed = 0,
    this.maxTeams = 0,
  });

  final String id;
  final String name;
  final String colorHex;
  final String tournamentId;
  final String tournamentName;
  final String tournamentStatus;
  final int minPlayers;
  final int maxPlayers;
  final int membersCount;
  final List<TeamMember> members;
  final int missingPositions;
  final List<PendingItem> requests;
  final List<PendingItem> invites;
  final bool isMember;
  final bool isHost;
  final String? pendingRequestId;
  final String? pendingInviteId;
  final bool canRequestToJoin;
  final String? joinBlockedReason;

  /// Equipa confirmada: completa e com todos os jogadores pagos. Fica fechada.
  final bool confirmed;

  /// Definições do lobby (o líder altera-as a qualquer momento).
  final bool closedToRequests;
  final bool membersCanInvite;

  /// Eu posso convidar (líder, ou membro quando o líder o permite).
  final bool canInvite;
  final int teamsConfirmed;
  final int maxTeams;

  Color get color => colorFromHex(colorHex);

  /// Jogadores que ainda não pagaram (só se conhece a lista se fores membro).
  int get unpaidCount => members.where((m) => m.paid == false).length;
  bool get registrationOpen => tournamentStatus == 'registration_open';
  bool get belowMinimum => membersCount < minPlayers;

  TeamMember? get me {
    for (final m in members) {
      if (m.isMe) {
        return m;
      }
    }
    return null;
  }

  factory TeamLobby.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> map(String key) =>
        Map<String, dynamic>.from((j[key] as Map?) ?? const {});
    List<Map<String, dynamic>> list(String key) => ((j[key] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final team = map('team');
    final t = map('tournament');
    final me = map('me');
    return TeamLobby(
      id: team['id'].toString(),
      name: (team['name'] ?? '').toString(),
      colorHex: (team['colorHex'] ?? '#888888').toString(),
      tournamentId: t['id'].toString(),
      tournamentName: (t['name'] ?? '').toString(),
      tournamentStatus: (t['status'] ?? '').toString(),
      minPlayers: (t['minPlayers'] as num?)?.toInt() ?? 0,
      maxPlayers: (t['maxPlayers'] as num?)?.toInt() ?? 0,
      membersCount: (j['membersCount'] as num?)?.toInt() ?? 0,
      members: list('members').map(TeamMember.fromJson).toList(),
      missingPositions: (j['missingPositions'] as num?)?.toInt() ?? 0,
      requests: list('requests').map(PendingItem.fromJson).toList(),
      invites: list('invites').map(PendingItem.fromJson).toList(),
      isMember: me['isMember'] == true,
      isHost: me['isHost'] == true,
      pendingRequestId: me['pendingRequestId']?.toString(),
      pendingInviteId: me['pendingInviteId']?.toString(),
      canRequestToJoin: me['canRequestToJoin'] == true,
      joinBlockedReason: me['joinBlockedReason'] as String?,
      confirmed: team['confirmed'] == true,
      closedToRequests: team['closedToRequests'] == true,
      membersCanInvite: team['membersCanInvite'] == true,
      canInvite: me['canInvite'] == true,
      teamsConfirmed: (t['teamsConfirmed'] as num?)?.toInt() ?? 0,
      maxTeams: (t['maxTeams'] as num?)?.toInt() ?? 0,
    );
  }
}

class MyTeam {
  const MyTeam({
    required this.teamId,
    required this.name,
    required this.colorHex,
    required this.tournamentName,
    required this.tournamentStatus,
    required this.isHost,
    required this.membersCount,
    required this.minPlayers,
    required this.maxPlayers,
    required this.pendingRequests,
  });

  final String teamId;
  final String name;
  final String colorHex;
  final String tournamentName;
  final String tournamentStatus;
  final bool isHost;
  final int membersCount;
  final int minPlayers;
  final int maxPlayers;
  final int pendingRequests;

  Color get color => colorFromHex(colorHex);

  factory MyTeam.fromJson(Map<String, dynamic> j) => MyTeam(
        teamId: j['teamId'].toString(),
        name: (j['name'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        tournamentStatus: (j['tournamentStatus'] ?? '').toString(),
        isHost: j['isHost'] == true,
        membersCount: (j['membersCount'] as num?)?.toInt() ?? 0,
        minPlayers: (j['minPlayers'] as num?)?.toInt() ?? 0,
        maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? 0,
        pendingRequests: (j['pendingRequests'] as num?)?.toInt() ?? 0,
      );
}

/// Convite recebido ([invitedByName] preenchido) ou pedido enviado (vazio).
class MyInvolvement {
  const MyInvolvement({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    required this.tournamentName,
    this.invitedByName,
  });

  final String id;
  final String teamId;
  final String teamName;
  final String colorHex;
  final String tournamentName;
  final String? invitedByName;

  Color get color => colorFromHex(colorHex);

  factory MyInvolvement.fromJson(Map<String, dynamic> j) => MyInvolvement(
        id: j['id'].toString(),
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        invitedByName: j['invitedByName'] as String?,
      );
}
