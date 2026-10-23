import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/theme.dart';
import '../../widgets/load_view.dart';
import 'game_detail_screen.dart';
import 'game_models.dart';
import 'game_widgets.dart';
import 'games_repository.dart';

/// Quadro de eliminatórias: uma coluna por ronda (desliza para os lados) + jogo do 3.º/4.º lugar.
class BracketTab extends StatelessWidget {
  const BracketTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final repo = GamesRepository(AuthScope.of(context).api);
    return LoadView<Bracket>(
      load: () async => Bracket.fromGames(await repo.games(tournamentId)),
      builder: (context, bracket) {
        if (bracket.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('O quadro de eliminatórias ainda não foi definido.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ),
          ];
        }
        return [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final round in bracket.rounds) _RoundColumn(round: round),
              ],
            ),
          ),
          if (bracket.thirdPlace.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('3.º e 4.º lugar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final g in bracket.thirdPlace) _BracketGame(game: g),
          ],
          const SizedBox(height: 12),
          const Text('Desliza para os lados para ver todas as rondas.',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ];
      },
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({required this.round});

  final BracketRound round;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(round.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final g in round.games) _BracketGame(game: g),
        ],
      ),
    );
  }
}

class _BracketGame extends StatelessWidget {
  const _BracketGame({required this.game});

  final Game game;

  Widget _line(GameTeam team, int? goals, bool won) => Row(
        children: [
          TeamDot(team.color, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              team.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: won ? FontWeight.w800 : FontWeight.w500,
                color: team.isKnown ? Colors.white : Colors.white54,
                fontStyle: team.isKnown ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
          if (goals != null)
            Text('$goals', style: TextStyle(fontWeight: won ? FontWeight.w900 : FontWeight.w600)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final g = game;
    final w = g.winner;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => GameDetailScreen(gameId: g.id)),
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GhColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(g.home, g.hasScore ? g.homeGoals : null, w != null && w == g.home),
                const SizedBox(height: 4),
                _line(g.away, g.hasScore ? g.awayGoals : null, w != null && w == g.away),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GameStatusChip(status: g.status),
                    if (g.penaltiesText != null) ...[
                      const SizedBox(width: 6),
                      Text(g.penaltiesText!,
                          style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
