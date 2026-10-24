import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../teams/team_lobby_screen.dart';
import '../teams/team_widgets.dart';
import '../teams/teams_repository.dart';
import 'notification_models.dart';
import 'notifications_repository.dart';

/// Central de notificações. Por agora só tem convites para equipas (com aceitar/recusar).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationsRepository _repo;
  late TeamsRepository _teams;
  bool _started = false;

  NotificationList? _data;
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final api = AuthScope.of(context).api;
      _repo = NotificationsRepository(api);
      _teams = TeamsRepository(api);
      _load(markRead: true);
    }
  }

  Future<void> _load({bool markRead = false}) async {
    try {
      final data = await _repo.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _error = null;
      });
      if (markRead && data.unreadCount > 0) {
        // Abrir a central conta como ver as notificações: o pontinho vermelho desaparece.
        // O "Novo" fica visível nesta visita porque a lista já foi carregada.
        try {
          await _repo.markAllRead();
        } catch (e) {
          debugPrint('[GameHall] marcar notificações como lidas falhou: $e');
        }
      }
    } catch (e, st) {
      debugPrint('[GameHall] notificações falharam: $e\n$st');
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
  }

  Future<void> _answer(TeamInviteInfo invite, {required bool accept}) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (accept) {
        await _teams.acceptInvite(invite.inviteId);
        _info = 'Entraste na equipa ${invite.teamName}.';
      } else {
        await _teams.declineInvite(invite.inviteId);
        _info = 'Convite recusado.';
      }
    } catch (e, st) {
      debugPrint('[GameHall] resposta ao convite falhou: $e\n$st');
      _error = friendlyError(e);
    }
    if (mounted) {
      await _load();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openTeam(String teamId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TeamLobbyScreen(teamId: teamId)),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return GhPage(
      title: 'Notificações',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          icon: const Icon(Icons.refresh),
          onPressed: _busy ? null : () => _load(),
        ),
      ],
      children: [
        if (_error != null) GhBanner.error(_error!),
        if (_info != null) GhBanner.success(_info!),
        if (data == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        if (data == null && _error != null) GhButton(label: 'Tentar novamente', onPressed: _load),
        if (data != null && data.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Ainda não tens notificações. Quando alguém te convidar para uma equipa, aparece aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        if (data != null)
          for (final n in data.items)
            if (n.type == AppNotification.teamInvite && n.invite != null)
              InviteNotificationCard(
                notification: n,
                busy: _busy,
                onOpenTeam: () => _openTeam(n.invite!.teamId),
                onAccept: () => _answer(n.invite!, accept: true),
                onDecline: () => _answer(n.invite!, accept: false),
              ),
      ],
    );
  }
}

/// Cartão de um convite para uma equipa: quem convidou, para onde, e aceitar/recusar enquanto estiver pendente.
class InviteNotificationCard extends StatelessWidget {
  const InviteNotificationCard({
    super.key,
    required this.notification,
    required this.busy,
    required this.onOpenTeam,
    required this.onAccept,
    required this.onDecline,
  });

  final AppNotification notification;
  final bool busy;
  final VoidCallback onOpenTeam;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final invite = n.invite!;
    final outcome = NotificationLabels.inviteOutcome(invite.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: n.read ? GhColors.fieldBorder : GhColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorDot(invite.color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Convite para a equipa ${invite.teamName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (!n.read)
                const Text('Novo', style: TextStyle(color: GhColors.success, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${invite.invitedByLabel} convidou-te para jogar em ${invite.tournamentName}.',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            NotificationLabels.ago(n.createdAt),
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (invite.isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GhColors.error,
                      side: const BorderSide(color: GhColors.error),
                    ),
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: const Text('Aceitar'),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(outcome ?? '', style: const TextStyle(color: Colors.white70)),
                ),
                if (invite.status == 'accepted')
                  TextButton(onPressed: onOpenTeam, child: const Text('Ver equipa')),
              ],
            ),
          if (invite.isPending)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onOpenTeam, child: const Text('Ver equipa e jogadores')),
            ),
        ],
      ),
    );
  }
}
