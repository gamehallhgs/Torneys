import 'package:flutter/painting.dart';

import '../teams/team_models.dart';

/// Convite para entrar numa equipa (dentro de uma notificação).
/// [status]: pending, accepted, declined, cancelled.
class TeamInviteInfo {
  const TeamInviteInfo({
    required this.inviteId,
    required this.status,
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    required this.tournamentId,
    required this.tournamentName,
    required this.invitedByName,
    this.invitedByUsername = '',
  });

  final String inviteId;
  final String status;
  final String teamId;
  final String teamName;
  final String colorHex;
  final String tournamentId;
  final String tournamentName;
  final String invitedByName;
  final String invitedByUsername;

  /// "Tomás Alves (@tomas)"
  String get invitedByLabel => invitedByUsername.isEmpty ? invitedByName : '$invitedByName (@$invitedByUsername)';

  bool get isPending => status == 'pending';
  Color get color => colorFromHex(colorHex);

  factory TeamInviteInfo.fromJson(Map<String, dynamic> j) => TeamInviteInfo(
        inviteId: j['inviteId'].toString(),
        status: (j['status'] ?? '').toString(),
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        tournamentId: j['tournamentId'].toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        invitedByName: (j['invitedByName'] ?? '').toString(),
        invitedByUsername: (j['invitedByUsername'] ?? '').toString(),
      );
}

/// Pedido para entrar na minha equipa (visto pelo líder). [status]: pending, accepted, rejected, cancelled.
class JoinRequestInfo {
  const JoinRequestInfo({
    required this.requestId,
    required this.status,
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    required this.tournamentName,
    required this.requesterName,
    this.requesterUsername = '',
  });

  final String requestId;
  final String status;
  final String teamId;
  final String teamName;
  final String colorHex;
  final String tournamentName;
  final String requesterName;
  final String requesterUsername;

  String get requesterLabel => requesterUsername.isEmpty ? requesterName : '$requesterName (@$requesterUsername)';

  bool get isPending => status == 'pending';
  Color get color => colorFromHex(colorHex);

  factory JoinRequestInfo.fromJson(Map<String, dynamic> j) => JoinRequestInfo(
        requestId: j['requestId'].toString(),
        status: (j['status'] ?? '').toString(),
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        requesterName: (j['requesterName'] ?? '').toString(),
        requesterUsername: (j['requesterUsername'] ?? '').toString(),
      );
}

/// Evento de equipa (fechada, vaga reservada, confirmada): só informativo, com o texto já composto.
class TeamEventInfo {
  const TeamEventInfo({
    required this.teamId,
    required this.teamName,
    required this.colorHex,
    required this.tournamentName,
    required this.title,
    required this.message,
    required this.teamExists,
  });

  final String teamId;
  final String teamName;
  final String colorHex;
  final String tournamentName;
  final String title;
  final String message;
  final bool teamExists;

  Color get color => colorFromHex(colorHex);

  factory TeamEventInfo.fromJson(Map<String, dynamic> j) => TeamEventInfo(
        teamId: j['teamId'].toString(),
        teamName: (j['teamName'] ?? '').toString(),
        colorHex: (j['colorHex'] ?? '#888888').toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        teamExists: j['teamExists'] == true,
      );
}

/// Aviso sobre um torneio ou jogo (votação, jogo a começar, jogo alterado): texto já composto.
class TournamentEventInfo {
  const TournamentEventInfo({
    required this.tournamentId,
    required this.tournamentName,
    required this.title,
    required this.message,
    required this.tournamentExists,
    this.gameId,
  });

  final String tournamentId;
  final String tournamentName;
  final String? gameId;
  final String title;
  final String message;
  final bool tournamentExists;

  factory TournamentEventInfo.fromJson(Map<String, dynamic> j) => TournamentEventInfo(
        tournamentId: j['tournamentId'].toString(),
        tournamentName: (j['tournamentName'] ?? '').toString(),
        gameId: j['gameId']?.toString(),
        title: (j['title'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        tournamentExists: j['tournamentExists'] == true,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.read,
    this.invite,
    this.request,
    this.event,
    this.info,
  });

  static const teamInvite = 'team_invite';
  static const joinRequest = 'join_request';
  static const teamClosed = 'team_closed';
  static const slotReserved = 'slot_reserved';
  static const teamConfirmed = 'team_confirmed';
  static const requestDecided = 'request_decided';
  static const reservationExpiring = 'reservation_expiring';
  static const reservationExpired = 'reservation_expired';
  static const teamEliminated = 'team_eliminated';
  static const removedFromTeam = 'removed_from_team';
  static const nowLeader = 'now_leader';
  static const memberJoined = 'member_joined';
  static const votingOpened = 'voting_opened';
  static const votingSecondRound = 'voting_second_round';
  static const votingResults = 'voting_results';
  static const gameStarting = 'game_starting';
  static const gameChanged = 'game_changed';

  /// Avisos sobre um torneio/jogo (guardam [info]).
  static const infoTypes = {votingOpened, votingSecondRound, votingResults, gameStarting, gameChanged};

  static const eventTypes = {
    memberJoined,
    teamClosed,
    slotReserved,
    teamConfirmed,
    requestDecided,
    reservationExpiring,
    reservationExpired,
    teamEliminated,
    removedFromTeam,
    nowLeader,
  };

  final String id;
  final String type;
  final DateTime createdAt;
  final bool read;
  final TeamInviteInfo? invite;
  final JoinRequestInfo? request;
  final TeamEventInfo? event;
  final TournamentEventInfo? info;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final invite = j['invite'];
    final request = j['request'];
    final event = j['event'];
    final info = j['info'];
    return AppNotification(
      id: j['id'].toString(),
      type: (j['type'] ?? '').toString(),
      createdAt: DateTime.parse(j['createdAt'].toString()).toLocal(),
      read: j['read'] == true,
      invite: invite is Map ? TeamInviteInfo.fromJson(Map<String, dynamic>.from(invite)) : null,
      request: request is Map ? JoinRequestInfo.fromJson(Map<String, dynamic>.from(request)) : null,
      event: event is Map ? TeamEventInfo.fromJson(Map<String, dynamic>.from(event)) : null,
      info: info is Map ? TournamentEventInfo.fromJson(Map<String, dynamic>.from(info)) : null,
    );
  }
}

class NotificationList {
  const NotificationList({required this.unreadCount, required this.items});

  final int unreadCount;
  final List<AppNotification> items;

  factory NotificationList.fromJson(Map<String, dynamic> j) => NotificationList(
        unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class NotificationLabels {
  NotificationLabels._();

  /// "agora", "há 5 min", "há 3 h", "há 2 dias" (e a data a partir de uma semana).
  static String ago(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inMinutes < 1) {
      return 'agora';
    }
    if (d.inMinutes < 60) {
      return 'há ${d.inMinutes} min';
    }
    if (d.inHours < 24) {
      return 'há ${d.inHours} h';
    }
    if (d.inDays == 1) {
      return 'há 1 dia';
    }
    if (d.inDays < 7) {
      return 'há ${d.inDays} dias';
    }
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  /// Estado final de um convite já tratado (null se ainda está pendente).
  static String? inviteOutcome(String status) => switch (status) {
        'accepted' => 'Aceitaste o convite',
        'declined' => 'Recusaste o convite',
        'cancelled' => 'Convite cancelado ou expirado',
        _ => null,
      };

  /// Estado final de um pedido para entrar já tratado (null se ainda está pendente).
  static String? requestOutcome(String status) => switch (status) {
        'accepted' => 'Aceitaste o pedido',
        'rejected' => 'Recusaste o pedido',
        'cancelled' => 'Pedido cancelado',
        _ => null,
      };
}
