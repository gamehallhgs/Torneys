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
        'team_closed' => 'A equipa está fechada: ninguém entra nem sai.',
        'player_penalized' =>
          'Estás penalizado por não teres pago a tempo: ainda não podes entrar numa equipa deste torneio.',
        'lobby_private' => 'Esta equipa é privada: só se entra por convite.',
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
    this.ready,
    this.username = '',
    this.slot,
    this.penalized,
  });

  final String userId;
  final String displayName;

  /// @username (sem a tag, que é privada).
  final String username;
  final String? position;
  final bool isHost;
  final bool isMe;
  /// null = não sabes (só os membros da equipa veem os pagamentos).
  final bool? paid;

  /// Preparado para o pagamento (o líder conta sempre como preparado). null = só os membros veem.
  final bool? ready;

  /// Lugar no campo (0 = guarda-redes); null = suplente.
  final int? slot;

  /// Penalizado por não ter pago a tempo (só os membros da equipa veem; null = não sabes).
  final bool? penalized;

  /// "Nome (@username)" (só o nome se não houver username).
  String get label => username.isEmpty ? displayName : '$displayName (@$username)';

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        userId: j['userId'].toString(),
        displayName: (j['displayName'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        position: j['position'] as String?,
        isHost: j['isHost'] == true,
        isMe: j['isMe'] == true,
        paid: j['paid'] as bool?,
        ready: j['ready'] as bool?,
        slot: (j['slot'] as num?)?.toInt(),
        penalized: j['penalized'] as bool?,
      );
}

/// Formação escolhida, as disponíveis para a modalidade e nº de lugares em campo.
class Lineup {
  const Lineup({this.formation = '', this.formations = const [], this.slotCount = 0});

  final String formation;
  final List<String> formations;
  final int slotCount;

  factory Lineup.fromJson(Map<String, dynamic> j) => Lineup(
        formation: (j['formation'] ?? '').toString(),
        formations: ((j['formations'] as List?) ?? const []).map((e) => e.toString()).toList(),
        slotCount: (j['slotCount'] as num?)?.toInt() ?? 0,
      );

  /// Posições dos lugares no campo (x, y entre 0 e 1; y = 0 é a baliza da equipa, em baixo no desenho).
  /// "4-4-2" -> guarda-redes + 4 + 4 + 2 lugares, cada linha repartida em largura.
  static List<({double x, double y})> layout(String formation) {
    final lines = formation.split('-').map(int.tryParse).whereType<int>().toList();
    if (lines.isEmpty) {
      return const [];
    }
    final out = <({double x, double y})>[(x: 0.5, y: 0.0)];
    for (var i = 0; i < lines.length; i++) {
      final y = (i + 1) / (lines.length + 1);
      for (var k = 0; k < lines[i]; k++) {
        out.add((x: (k + 1) / (lines[i] + 1), y: y));
      }
    }
    return out;
  }
}

/// Pedido para entrar ou convite pendente (vistos pelo líder).
class PendingItem {
  const PendingItem({
    required this.id,
    required this.userId,
    required this.displayName,
    this.username = '',
  });

  final String id;
  final String userId;
  final String displayName;
  final String username;

  /// "Nome (@username)" (só o nome se não houver username).
  String get label => username.isEmpty ? displayName : '$displayName (@$username)';

  factory PendingItem.fromJson(Map<String, dynamic> j) => PendingItem(
        id: j['id'].toString(),
        userId: j['userId'].toString(),
        displayName: (j['displayName'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
      );
}

/// Estados da equipa: formação -> fechada em fila -> vaga reservada (a pagar) -> confirmada.
class TeamState {
  TeamState._();

  static const forming = 'forming';
  static const queued = 'queued';
  static const reserved = 'reserved';
  static const confirmed = 'confirmed';

  /// Nome do estado para mostrar ("Em pagamento" é a fase em que a vaga está reservada e todos têm de pagar).
  static String label(String state) => switch (state) {
        queued => 'Em fila',
        reserved => 'Em pagamento',
        confirmed => 'Confirmada',
        _ => 'Em formação',
      };
}

/// Fila e reserva de vaga (30 min para pagar; 15 min de penalização para quem não paga).
class TeamReservation {
  const TeamReservation({
    this.state = TeamState.forming,
    this.expiresAt,
    this.queuePosition,
    this.slotsTaken = 0,
    this.maxTeams = 0,
    this.reservationMinutes = 30,
    this.penaltyMinutes = 15,
  });

  final String state;
  final DateTime? expiresAt;
  final int? queuePosition;
  final int slotsTaken;
  final int maxTeams;
  final int reservationMinutes;
  final int penaltyMinutes;

  factory TeamReservation.fromJson(Map<String, dynamic> j, {bool confirmed = false}) => TeamReservation(
        state: (j['state'] as String?) ?? (confirmed ? TeamState.confirmed : TeamState.forming),
        expiresAt: j['expiresAt'] == null ? null : DateTime.tryParse(j['expiresAt'].toString()),
        queuePosition: (j['queuePosition'] as num?)?.toInt(),
        slotsTaken: (j['slotsTaken'] as num?)?.toInt() ?? 0,
        maxTeams: (j['maxTeams'] as num?)?.toInt() ?? 0,
        reservationMinutes: (j['reservationMinutes'] as num?)?.toInt() ?? 30,
        penaltyMinutes: (j['penaltyMinutes'] as num?)?.toInt() ?? 15,
      );
}

/// Valores a pagar (cêntimos). Antes de fechar, [mode] é null e [shareCents] é a pré-visualização dividida.
class TeamPayment {
  const TeamPayment({
    this.feeCents = 0,
    this.mode,
    this.shareCents = 0,
    this.members = 0,
    this.collectedCents = 0,
    this.extraCents = 0,
    this.roundedUp = false,
    this.paidCount = 0,
    this.iPaid = false,
    this.canPay = false,
    this.cannotPayReason,
  });

  final int feeCents;
  final String? mode;
  final int shareCents;
  final int members;
  final int collectedCents;
  final int extraCents;

  /// O valor dividido foi arredondado para cima (a equipa paga [extraCents] a mais).
  final bool roundedUp;
  final int paidCount;
  final bool iPaid;
  final bool canPay;
  final String? cannotPayReason;

  bool get isTotal => mode == 'total';

  factory TeamPayment.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return TeamPayment(
      feeCents: n('feeCents'),
      mode: j['mode'] as String?,
      shareCents: n('shareCents'),
      members: n('members'),
      collectedCents: n('collectedCents'),
      extraCents: n('extraCents'),
      roundedUp: j['roundedUp'] == true,
      paidCount: n('paidCount'),
      iPaid: j['iPaid'] == true,
      canPay: j['canPay'] == true,
      cannotPayReason: j['cannotPayReason'] as String?,
    );
  }
}

/// "m:ss" (ou "h:mm:ss") para o contador decrescente da reserva.
String formatCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
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
    this.isPrivate = false,
    this.membersCanInvite = false,
    this.canInvite = false,
    this.teamsConfirmed = 0,
    this.maxTeams = 0,
    this.reservation = const TeamReservation(),
    this.payment = const TeamPayment(),
    this.iAmReady = false,
    this.penaltyUntil,
    this.canClose = false,
    this.closeBlockedReason,
    this.closeBlockedMessage,
    this.canReopen = false,
    this.canDisband = false,
    this.lineup = const Lineup(),
    this.rules = '',
    this.inviteCode,
  });

  final Lineup lineup;

  /// Código de convite (null se não o podes ver ou a equipa já fechou).
  final TeamCode? inviteCode;

  /// Regras do torneio (definidas pelo gestor; por agora um texto de exemplo).
  final String rules;
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
  /// Equipa privada = não aceita pedidos de entrada (só convites). Não confundir com equipa "fechada".
  final bool isPrivate;
  final bool membersCanInvite;

  /// Fila e reserva de vaga, valores a pagar e o que eu posso fazer.
  final TeamReservation reservation;
  final TeamPayment payment;
  final bool iAmReady;

  /// Até quando estou penalizado (não posso reservar vaga), se ainda estiver.
  final DateTime? penaltyUntil;
  final bool canClose;
  final String? closeBlockedReason;
  final String? closeBlockedMessage;
  final bool canReopen;
  final bool canDisband;

  /// Eu posso convidar (líder, ou membro quando o líder o permite).
  final bool canInvite;
  final int teamsConfirmed;
  final int maxTeams;

  Color get color => colorFromHex(colorHex);

  String get state => reservation.state;
  bool get isForming => state == TeamState.forming;
  bool get isQueued => state == TeamState.queued;
  bool get isReserved => state == TeamState.reserved;

  /// Fechada pelo líder (em fila, a pagar ou confirmada): ninguém entra nem sai.
  bool get isClosed => !isForming;

  /// Segundos que faltam para a reserva expirar (0 se não há reserva).
  int get secondsLeft {
    final e = reservation.expiresAt;
    return e == null ? 0 : e.difference(DateTime.now()).inSeconds;
  }

  bool get isPenalized => penaltyUntil != null && penaltyUntil!.isAfter(DateTime.now());

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
    final confirmed = team['confirmed'] == true;
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
      confirmed: confirmed,
      isPrivate: team['isPrivate'] == true,
      membersCanInvite: team['membersCanInvite'] == true,
      canInvite: me['canInvite'] == true,
      teamsConfirmed: (t['teamsConfirmed'] as num?)?.toInt() ?? 0,
      maxTeams: (t['maxTeams'] as num?)?.toInt() ?? 0,
      reservation: TeamReservation.fromJson(map('reservation'), confirmed: confirmed),
      payment: TeamPayment.fromJson(map('payment')),
      iAmReady: me['ready'] == true,
      penaltyUntil: me['penaltyUntil'] == null ? null : DateTime.tryParse(me['penaltyUntil'].toString()),
      canClose: me['canClose'] == true,
      closeBlockedReason: me['closeBlockedReason'] as String?,
      closeBlockedMessage: me['closeBlockedMessage'] as String?,
      canReopen: me['canReopen'] == true,
      canDisband: me['canDisband'] == true,
      lineup: Lineup.fromJson(map('lineup')),
      rules: (t['rules'] ?? '').toString(),
      inviteCode: j['inviteCode'] is Map
          ? TeamCode.fromJson(Map<String, dynamic>.from(j['inviteCode'] as Map))
          : null,
    );
  }
}

/// Código de convite da equipa (GH-XXXX). [code] é null quando não o podes ver.
class TeamCode {
  const TeamCode({
    this.code,
    this.enabled = false,
    this.directEntry = true,
    this.membersSeeCode = false,
    this.regensLeft = 0,
  });

  final String? code;
  final bool enabled;

  /// Quem usa o código entra logo (senão fica um pedido para o líder aceitar).
  final bool directEntry;
  final bool membersSeeCode;

  /// Códigos novos que o líder ainda pode gerar esta hora (máx. 3).
  final int regensLeft;

  factory TeamCode.fromJson(Map<String, dynamic> j) => TeamCode(
        code: j['code'] as String?,
        enabled: j['enabled'] == true,
        directEntry: j['directEntry'] != false,
        membersSeeCode: j['membersSeeCode'] == true,
        regensLeft: (j['regensLeft'] as num?)?.toInt() ?? 0,
      );
}

/// O que se vê ao escrever um código, antes de entrar.
class CodePreview {
  const CodePreview({
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    required this.tournamentName,
    required this.membersCount,
    required this.maxPlayers,
    required this.directEntry,
    this.blockedMessage,
  });

  final String teamId;
  final String teamName;
  final String colorHex;
  final String tournamentName;
  final int membersCount;
  final int maxPlayers;
  final bool directEntry;

  /// Porque não podes entrar (null = podes).
  final String? blockedMessage;

  Color get color => colorFromHex(colorHex);

  factory CodePreview.fromJson(Map<String, dynamic> j) => CodePreview(
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        membersCount: (j['membersCount'] as num?)?.toInt() ?? 0,
        maxPlayers: (j['maxPlayers'] as num?)?.toInt() ?? 0,
        directEntry: j['directEntry'] != false,
        blockedMessage: j['blockedMessage'] as String?,
      );
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
    this.state = TeamState.forming,
    this.reservationExpiresAt,
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

  /// forming | queued | reserved | confirmed
  final String state;
  final DateTime? reservationExpiresAt;

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
        state: (j['state'] as String?) ?? TeamState.forming,
        reservationExpiresAt:
            j['reservationExpiresAt'] == null ? null : DateTime.tryParse(j['reservationExpiresAt'].toString()),
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
