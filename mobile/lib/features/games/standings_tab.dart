import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/theme.dart';
import '../../widgets/load_view.dart';
import '../tournaments/tournament_models.dart';
import 'game_models.dart';
import 'game_widgets.dart';
import 'games_repository.dart';

/// Classificação (liga ou grupos), com a legenda e os critérios de desempate do torneio.
class StandingsTab extends StatelessWidget {
  const StandingsTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final repo = GamesRepository(AuthScope.of(context).api);
    return LoadView<Standings>(
      load: () => repo.standings(tournamentId),
      builder: (context, s) {
        if (s.groups.isEmpty) {
          return const [
            Padding(
              padding: EdgeInsets.all(24),
              child: Text('A classificação ainda não está disponível.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ),
          ];
        }
        return [
          for (final group in s.groups) _GroupTable(group: group),
          const _Legend(),
          if (s.tiebreakers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Critérios de desempate (por ordem)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var i = 0; i < s.tiebreakers.length; i++)
              Text('${i + 1}. ${TournamentLabels.tiebreaker(s.tiebreakers[i])}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ];
      },
    );
  }
}

class _GroupTable extends StatelessWidget {
  const _GroupTable({required this.group});

  final StandingsGroup group;

  static const double _num = 28;

  Widget _cell(String text, {double width = _num, bool bold = false, Color? color}) => SizedBox(
        width: width,
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: color ?? Colors.white)),
      );

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w700);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.name != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(group.name!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          Row(
            children: [
              const SizedBox(width: 22),
              Expanded(child: Text('Equipa', style: header)),
              for (final h in const ['J', 'V', 'E', 'D'])
                SizedBox(width: _num, child: Text(h, textAlign: TextAlign.center, style: header)),
              SizedBox(width: 34, child: Text('DG', textAlign: TextAlign.center, style: header)),
              SizedBox(width: 34, child: Text('Pts', textAlign: TextAlign.center, style: header)),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          if (group.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sem equipas.', style: TextStyle(color: Colors.white70)),
            ),
          for (final r in group.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${r.position}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ),
                  TeamDot(r.color, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(r.name,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                  ),
                  _cell('${r.played}'),
                  _cell('${r.won}'),
                  _cell('${r.drawn}'),
                  _cell('${r.lost}'),
                  _cell(r.goalDifferenceText, width: 34),
                  _cell('${r.points}', width: 34, bold: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => const Text(
        'J jogos · V vitórias · E empates · D derrotas · DG diferença de golos · Pts pontos '
        '(vitória 3, empate 1). Só contam jogos terminados.',
        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
      );
}
