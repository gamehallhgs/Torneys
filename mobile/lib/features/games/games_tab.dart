import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../widgets/load_view.dart';
import 'game_detail_screen.dart';
import 'game_models.dart';
import 'game_widgets.dart';
import 'games_repository.dart';

enum _Filter { all, live, upcoming, finished }

/// Lista de jogos do torneio com filtros simples.
class GamesTab extends StatefulWidget {
  const GamesTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  State<GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<GamesTab> {
  _Filter _filter = _Filter.all;

  static const _labels = {
    _Filter.all: 'Todos',
    _Filter.live: 'A decorrer',
    _Filter.upcoming: 'Por jogar',
    _Filter.finished: 'Terminados',
  };

  bool _matches(Game g) => switch (_filter) {
        _Filter.all => true,
        _Filter.live => g.status == 'running',
        _Filter.upcoming => g.status == 'scheduled' || g.status == 'postponed',
        _Filter.finished => g.status == 'finished',
      };

  @override
  Widget build(BuildContext context) {
    final repo = GamesRepository(AuthScope.of(context).api);
    return LoadView<List<Game>>(
      load: () => repo.games(widget.tournamentId),
      builder: (context, games) {
        final shown = games.where(_matches).toList();
        return [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final f in _Filter.values)
                ChoiceChip(
                  label: Text(_labels[f]!),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (games.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ainda não há jogos marcados.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            )
          else if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nenhum jogo neste filtro.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ),
          for (final g in shown)
            GameCard(
              game: g,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => GameDetailScreen(gameId: g.id)),
              ),
            ),
        ];
      },
    );
  }
}
