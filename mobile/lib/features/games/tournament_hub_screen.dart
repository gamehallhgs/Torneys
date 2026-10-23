import 'package:flutter/material.dart';

import '../../widgets/gh_widgets.dart';
import 'bracket_tab.dart';
import 'games_tab.dart';
import 'standings_tab.dart';
import 'stats_tab.dart';

/// Jogos, classificação, quadro e estatísticas de um torneio. Os separadores dependem do formato.
class TournamentHubScreen extends StatelessWidget {
  const TournamentHubScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.format,
  });

  final String tournamentId;
  final String tournamentName;
  final String format;

  /// Liga e fase de grupos têm tabela; eliminatórias e fase de grupos têm quadro.
  static bool hasStandings(String format) => format == 'league' || format == 'groups_knockout';
  static bool hasBracket(String format) => format != 'league';

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, Widget)>[
      ('Jogos', GamesTab(tournamentId: tournamentId)),
      if (hasStandings(format)) ('Classificação', StandingsTab(tournamentId: tournamentId)),
      if (hasBracket(format)) ('Quadro', BracketTab(tournamentId: tournamentId)),
      ('Estatísticas', StatsTab(tournamentId: tournamentId)),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(tournamentName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          bottom: TabBar(
            isScrollable: tabs.length > 3,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [for (final t in tabs) Tab(text: t.$1)],
          ),
        ),
        body: GhBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: TabBarView(children: [for (final t in tabs) t.$2]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
