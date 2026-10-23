import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'game_models.dart';

class TeamDot extends StatelessWidget {
  const TeamDot(this.color, {super.key, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
      );
}

class GameStatusChip extends StatelessWidget {
  const GameStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'running' => GhColors.success,
      'finished' => Colors.white70,
      'cancelled' => GhColors.error,
      'postponed' => Colors.amber,
      _ => Colors.lightBlueAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        GameLabels.status(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Cartão de jogo: título, estado, equipas, resultado e hora/campo.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.onTap});

  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final when = g.scheduledAt == null ? null : Fmt.dateTime(g.scheduledAt!);
    final where = [if (when != null) when, if (g.fieldName != null) g.fieldName!].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GhColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(g.title,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    GameStatusChip(status: g.status),
                  ],
                ),
                const SizedBox(height: 10),
                _TeamLine(team: g.home, goals: g.hasScore ? g.homeGoals : null, bold: g.winner == g.home && g.winner != null),
                const SizedBox(height: 6),
                _TeamLine(team: g.away, goals: g.hasScore ? g.awayGoals : null, bold: g.winner == g.away && g.winner != null),
                if (g.penaltiesText != null) ...[
                  const SizedBox(height: 6),
                  Text('Penáltis ${g.penaltiesText!}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(where, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
                if (g.highlightsCount > 0) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.play_circle_outline, size: 16, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('Tem vídeo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team, required this.goals, required this.bold});

  final GameTeam team;
  final int? goals;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamDot(team.color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            team.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: team.isKnown ? Colors.white : Colors.white54,
              fontStyle: team.isKnown ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
        if (goals != null)
          Text('$goals',
              style: TextStyle(fontSize: 18, fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
      ],
    );
  }
}
