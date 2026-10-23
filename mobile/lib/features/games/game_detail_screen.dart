import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/load_view.dart';
import 'game_models.dart';
import 'game_widgets.dart';
import 'games_repository.dart';
import 'highlight_player_screen.dart';

/// Detalhe do jogo: resultado, estado, eventos (golos, assistências, cartões) e vídeos de destaque.
class GameDetailScreen extends StatelessWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final repo = GamesRepository(AuthScope.of(context).api);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Jogo', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: GhBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: LoadView<GameDetail>(
                load: () => repo.game(gameId),
                builder: (context, d) => _content(context, d),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, GameDetail d) {
    final g = d.game;
    final when = g.scheduledAt == null ? null : Fmt.dateTime(g.scheduledAt!);
    return [
      Text(d.tournamentName, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 4),
      Text(g.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GhColors.fieldFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GhColors.fieldBorder),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _TeamColumn(team: g.home)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(g.scoreText,
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      if (g.penaltiesText != null)
                        Text(g.penaltiesText!,
                            style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(child: _TeamColumn(team: g.away)),
              ],
            ),
            const SizedBox(height: 12),
            GameStatusChip(status: g.status),
            if (when != null || g.fieldName != null) ...[
              const SizedBox(height: 8),
              Text([if (when != null) when, if (g.fieldName != null) g.fieldName!].join(' · '),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
            if (g.status == 'postponed')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Jogo adiado. A nova data será indicada pela organização.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.amber, fontSize: 12)),
              ),
            if (g.status == 'cancelled')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Jogo cancelado.',
                    style: TextStyle(color: GhColors.error, fontSize: 12)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _Section(
        title: 'Eventos',
        children: [
          if (d.events.isEmpty)
            const Text('Sem eventos registados.', style: TextStyle(color: Colors.white70)),
          for (final e in d.events) _EventRow(event: e, isHome: e.teamId == g.home.id),
        ],
      ),
      _Section(
        title: 'Vídeos de destaque',
        children: [
          if (d.highlights.isEmpty)
            const Text('Ainda não há vídeos deste jogo.', style: TextStyle(color: Colors.white70)),
          for (final h in d.highlights)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_fill, size: 36),
              title: Text(h.title ?? 'Destaque'),
              subtitle: Text('${h.durationSeconds} s'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => HighlightPlayerScreen(highlight: h)),
              ),
            ),
        ],
      ),
    ];
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team});

  final GameTeam team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamDot(team.color, size: 36),
        const SizedBox(height: 8),
        Text(team.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: team.isKnown ? Colors.white : Colors.white54,
            )),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Linha de evento: equipa da casa à esquerda, visitante à direita.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.isHome});

  final GameEvent event;
  final bool isHome;

  Widget _icon() => switch (event.type) {
        'goal' => const Icon(Icons.sports_soccer, size: 18),
        'assist' => const Icon(Icons.north_east, size: 18, color: Colors.white70),
        'yellow_card' => _card(Colors.yellow),
        'red_card' => _card(Colors.red),
        _ => const Icon(Icons.circle, size: 10),
      };

  Widget _card(Color color) => Container(
        width: 12,
        height: 17,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      );

  @override
  Widget build(BuildContext context) {
    final minute = event.minute == null ? '' : "${event.minute}'";
    final isAssist = event.type == 'assist';
    final text = Column(
      crossAxisAlignment: isHome ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(event.playerName,
            style: TextStyle(
                fontSize: 14,
                fontWeight: isAssist ? FontWeight.w400 : FontWeight.w700,
                color: isAssist ? Colors.white70 : Colors.white)),
        Text(GameLabels.event(event.type),
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
    final minuteText = SizedBox(
      width: 36,
      child: Text(minute,
          textAlign: isHome ? TextAlign.left : TextAlign.right,
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        label: '$minute ${GameLabels.event(event.type)}: ${event.playerName}',
        child: Row(
          mainAxisAlignment: isHome ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: isHome
              ? [minuteText, _icon(), const SizedBox(width: 10), Flexible(child: text)]
              : [Flexible(child: text), const SizedBox(width: 10), _icon(), minuteText],
        ),
      ),
    );
  }
}
