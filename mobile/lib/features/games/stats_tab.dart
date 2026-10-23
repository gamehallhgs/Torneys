import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/theme.dart';
import '../../widgets/load_view.dart';
import 'game_models.dart';
import 'game_widgets.dart';
import 'games_repository.dart';

/// Melhores marcadores, assistentes e cartões do torneio.
class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final repo = GamesRepository(AuthScope.of(context).api);
    return LoadView<TournamentStats>(
      load: () => repo.stats(tournamentId),
      builder: (context, s) {
        if (s.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ainda não há estatísticas.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ),
          ];
        }
        return [
          _StatBox(title: 'Melhores marcadores', lines: s.scorers, unit: 'golos'),
          _StatBox(title: 'Assistências', lines: s.assists, unit: 'assist.'),
          _StatBox(title: 'Cartões amarelos', lines: s.yellowCards, unit: 'cartões'),
          _StatBox(title: 'Cartões vermelhos', lines: s.redCards, unit: 'cartões'),
        ];
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.title, required this.lines, required this.unit});

  final String title;
  final List<StatLine> lines;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (lines.isEmpty) const Text('Sem registos.', style: TextStyle(color: Colors.white70)),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text('${i + 1}', style: const TextStyle(color: Colors.white60)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lines[i].playerName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            TeamDot(lines[i].color, size: 10),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(lines[i].teamName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text('${lines[i].total}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 4),
                  Text(unit, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
