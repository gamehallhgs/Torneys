import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../teams/team_lobby_screen.dart';
import '../tournaments/tournament_detail_screen.dart';
import '../teams/team_widgets.dart';
import '../teams/teams_repository.dart';
import 'notification_models.dart';
import 'notifications_repository.dart';

/// Central de notificações: convites e pedidos para entrar (com aceitar/recusar) e avisos da equipa
/// (fechada, vaga reservada, confirmada).
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
        // Aceitou: abre logo o lobby da equipa (em vez de ficar nas notificações).
        if (mounted) {
          setState(() => _busy = false);
          await _openTeam(invite.teamId);
          return;
        }
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

  Future<void> _answerRequest(JoinRequestInfo request, {required bool accept}) async {
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
        await _teams.acceptRequest(request.requestId);
        _info = '${request.requesterName} entrou na equipa ${request.teamName}.';
      } else {
        await _teams.rejectRequest(request.requestId);
        _info = 'Pedido recusado.';
      }
    } catch (e, st) {
      debugPrint('[GameHall] resposta ao pedido falhou: $e\n$st');
      _error = friendlyError(e);
    }
    if (mounted) {
      await _load();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(AppNotification n) async {
    // Sai da lista logo; se o servidor falhar, volta a carregar.
    setState(() {
      _data = NotificationList(unreadCount: _data!.unreadCount, items: _data!.items.where((x) => x.id != n.id).toList());
    });
    try {
      await _repo.delete(n.id);
    } catch (e, st) {
      debugPrint('[GameHall] apagar notificação falhou: $e\n$st');
      if (mounted) {
        setState(() => _error = friendlyError(e));
        await _load();
      }
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GhColors.surface,
        title: const Text('Limpar tudo'),
        content: const Text('Apagar todas as notificações? Os convites e pedidos pendentes continuam a poder ser respondidos nas equipas.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Limpar tudo')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await _repo.deleteAll();
    } catch (e, st) {
      debugPrint('[GameHall] limpar notificações falhou: $e\n$st');
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
    if (mounted) {
      await _load();
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

  Future<void> _openTournament(TournamentEventInfo info) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TournamentDetailScreen(tournamentId: info.tournamentId, initialName: info.tournamentName),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Widget _card(AppNotification n) {
    if (n.type == AppNotification.teamInvite && n.invite != null) {
      return InviteNotificationCard(
        notification: n,
        busy: _busy,
        onOpenTeam: () => _openTeam(n.invite!.teamId),
        onAccept: () => _answer(n.invite!, accept: true),
        onDecline: () => _answer(n.invite!, accept: false),
      );
    }
    if (n.type == AppNotification.joinRequest && n.request != null) {
      return JoinRequestNotificationCard(
        notification: n,
        busy: _busy,
        onOpenTeam: () => _openTeam(n.request!.teamId),
        onAccept: () => _answerRequest(n.request!, accept: true),
        onDecline: () => _answerRequest(n.request!, accept: false),
      );
    }
    if (AppNotification.infoTypes.contains(n.type) && n.info != null) {
      final info = n.info!;
      return TournamentEventNotificationCard(
        notification: n,
        onOpenTournament: info.tournamentExists ? () => _openTournament(info) : null,
      );
    }
    if (AppNotification.eventTypes.contains(n.type) && n.event != null) {
      return TeamEventNotificationCard(
        notification: n,
        onOpenTeam: n.event!.teamExists ? () => _openTeam(n.event!.teamId) : null,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return GhPage(
      title: 'Notificações',
      actions: [
        if (data != null && data.items.isNotEmpty)
          TextButton(onPressed: _busy ? null : _clearAll, child: const Text('Limpar tudo')),
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
              'Ainda não tens notificações. Convites, pedidos para entrar e avisos da tua equipa aparecem aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        if (data != null && data.items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Desliza uma notificação para a apagar.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        if (data != null)
          for (final n in data.items)
            Dismissible(
              key: ValueKey('notification-${n.id}'),
              onDismissed: (_) => _delete(n),
              background: const _DeleteBackground(alignment: Alignment.centerLeft),
              secondaryBackground: const _DeleteBackground(alignment: Alignment.centerRight),
              child: _card(n),
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

/// Pedido de alguém para entrar na minha equipa: aceitar/recusar enquanto estiver pendente.
class JoinRequestNotificationCard extends StatelessWidget {
  const JoinRequestNotificationCard({
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
    final request = n.request!;
    final outcome = NotificationLabels.requestOutcome(request.status);
    return _NotificationFrame(
      read: n.read,
      color: request.color,
      title: 'Pedido para entrar em ${request.teamName}',
      body: '${request.requesterLabel} quer entrar na tua equipa em ${request.tournamentName}.',
      createdAt: n.createdAt,
      footer: request.isPending
          ? Column(
              children: [
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
                      child: FilledButton(onPressed: busy ? null : onAccept, child: const Text('Aceitar')),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: onOpenTeam, child: const Text('Ver equipa')),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(outcome ?? '', style: const TextStyle(color: Colors.white70))),
                if (request.status == 'accepted')
                  TextButton(onPressed: onOpenTeam, child: const Text('Ver equipa')),
              ],
            ),
    );
  }
}

/// Aviso da equipa (fechada, vaga reservada, confirmada). O texto vem do servidor.
class TeamEventNotificationCard extends StatelessWidget {
  const TeamEventNotificationCard({super.key, required this.notification, this.onOpenTeam});

  final AppNotification notification;
  final VoidCallback? onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final e = n.event!;
    return _NotificationFrame(
      read: n.read,
      color: e.color,
      title: e.title,
      body: e.message,
      createdAt: n.createdAt,
      footer: onOpenTeam == null
          ? const Text('A equipa já não existe.', style: TextStyle(color: Colors.white60))
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onOpenTeam, child: const Text('Ver equipa')),
            ),
    );
  }
}

/// Aviso de votação, jogo a começar ou jogo alterado: texto e botão para abrir o torneio.
class TournamentEventNotificationCard extends StatelessWidget {
  const TournamentEventNotificationCard({super.key, required this.notification, this.onOpenTournament});

  final AppNotification notification;
  final VoidCallback? onOpenTournament;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final e = n.info!;
    return _NotificationFrame(
      read: n.read,
      color: GhColors.success,
      title: e.title,
      body: e.message,
      createdAt: n.createdAt,
      footer: onOpenTournament == null
          ? const Text('O torneio já não existe.', style: TextStyle(color: Colors.white60))
          : Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onOpenTournament, child: const Text('Ver torneio')),
            ),
    );
  }
}

class _NotificationFrame extends StatelessWidget {
  const _NotificationFrame({
    required this.read,
    required this.color,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.footer,
  });

  final bool read;
  final Color color;
  final String title;
  final String body;
  final DateTime createdAt;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: read ? GhColors.fieldBorder : GhColors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorDot(color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (!read) const Text('Novo', style: TextStyle(color: GhColors.success, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 4),
          Text(NotificationLabels.ago(createdAt), style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: GhColors.error.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_outline),
    );
  }
}
