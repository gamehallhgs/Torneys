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

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.read,
    this.invite,
  });

  static const teamInvite = 'team_invite';

  final String id;
  final String type;
  final DateTime createdAt;
  final bool read;
  final TeamInviteInfo? invite;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final invite = j['invite'];
    return AppNotification(
      id: j['id'].toString(),
      type: (j['type'] ?? '').toString(),
      createdAt: DateTime.parse(j['createdAt'].toString()).toLocal(),
      read: j['read'] == true,
      invite: invite is Map ? TeamInviteInfo.fromJson(Map<String, dynamic>.from(invite)) : null,
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
}
