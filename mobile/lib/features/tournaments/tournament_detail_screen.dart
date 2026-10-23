import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../games/tournament_hub_screen.dart';
import '../teams/create_team_screen.dart';
import '../teams/team_lobby_screen.dart';
import 'tournament_card.dart';
import 'tournament_models.dart';
import 'tournaments_repository.dart';

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.initialName,
  });

  final String tournamentId;
  final String initialName;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  TournamentDetail? _detail;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _detail = null;
    });
    try {
      final repo = TournamentsRepository(AuthScope.of(context).api);
      final detail = await repo.detail(widget.tournamentId);
      if (mounted) {
        setState(() => _detail = detail);
      }
    } catch (e) {
      debugPrint('[GameHall] detalhe do torneio falhou: $e');
      if (mounted) {
        setState(() => _error = friendlyError(e));
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

  Future<void> _createTeam(TournamentDetail d) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateTeamScreen(
          tournamentId: d.summary.id,
          tournamentName: d.summary.name,
          takenColors: d.teams.map((t) => t.colorHex).toList(),
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return GhPage(
      title: 'Torneio',
      children: [
        if (_error != null) ...[
          GhBanner.error(_error!),
          GhButton(label: 'Tentar novamente', onPressed: _load),
        ] else if (d == null) ...[
          Text(
            widget.initialName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        ] else
          ..._content(d),
      ],
    );
  }

  List<Widget> _content(TournamentDetail d) {
    final s = d.summary;
    return [
      if (d.myTeam != null) ...[
        _MyTeamCard(
          team: d.myTeam!,
          maxPlayers: d.maxPlayersPerTeam,
          onTap: () => _openTeam(d.myTeam!.id),
        ),
        const SizedBox(height: 16),
      ],
      Text(s.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(s.organizerName, style: const TextStyle(color: Colors.white60)),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StatusChip(status: s.status),
            if (s.showFullFlag) const FullFlag(),
          ],
        ),
      ),
      if (d.description != null && d.description!.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(d.description!, style: const TextStyle(height: 1.4)),
      ],
      const SizedBox(height: 20),
      _Section(
        title: 'Informação',
        children: [
          _Fact('Modalidade', TournamentLabels.sport(s.sport)),
          _Fact('Datas', Fmt.dateRange(s.startsOn, s.endsOn)),
          _Fact(
            'Local',
            d.locationAddress == null || d.locationAddress!.isEmpty
                ? s.placeLine
                : '${s.placeLine}\n${d.locationAddress}',
          ),
          _Fact('Idades', '${s.ageLabel} anos'),
          _Fact('Inscrição', '${Fmt.money(s.entryFeeCents)} por equipa'),
          _Fact('Inscrições até', Fmt.date(s.registrationClosesAt)),
          _Fact('Equipas', TournamentLabels.teamsLine(s.teamsConfirmed, s.maxTeams, s.teamsInFormation)),
          _Fact(
            'Jogadores por equipa',
            d.minPlayersPerTeam == d.maxPlayersPerTeam
                ? '${d.minPlayersPerTeam}'
                : '${d.minPlayersPerTeam} a ${d.maxPlayersPerTeam} (titulares e suplentes)',
          ),
        ],
      ),
      _Section(
        title: 'Regras',
        children: [
          _Fact('Formato', TournamentLabels.format(s.format)),
          if (s.format == 'single_elimination' ||
              s.format == 'double_elimination' ||
              s.format == 'groups_knockout')
            _Fact('Jogo do 3.º e 4.º lugar', d.hasThirdPlace ? 'Sim' : 'Não'),
          if (d.tiebreakers.isNotEmpty)
            _Fact(
              'Desempates (por ordem)',
              [
                for (var i = 0; i < d.tiebreakers.length; i++)
                  '${i + 1}. ${TournamentLabels.tiebreaker(d.tiebreakers[i])}',
              ].join('\n'),
            ),
        ],
      ),
      _Section(
        title: 'Equipas (${d.teams.length})',
        children: [
          if (s.status == 'registration_open')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Qualquer pessoa pode criar equipas. Uma equipa só fica confirmada quando tem o mínimo de '
                'jogadores e todos pagaram: ficam no torneio as primeiras ${s.maxTeams} equipas confirmadas.',
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
              ),
            ),
          if (d.teams.isEmpty)
            const Text('Ainda não há equipas inscritas.', style: TextStyle(color: Colors.white70)),
          for (final team in d.teams)
            InkWell(
              onTap: () => _openTeam(team.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: team.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(team.name, style: const TextStyle(fontSize: 15))),
                    if (team.confirmed)
                      const Tooltip(
                        message: 'Confirmada',
                        child: Icon(Icons.check_circle, size: 18, color: GhColors.success),
                      )
                    else
                      const Text('em formação', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                  ],
                ),
              ),
            ),
        ],
      ),
      if (s.status != 'registration_open') ...[
        GhButton(
          label: 'Jogos, classificação e estatísticas',
          secondary: true,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TournamentHubScreen(
                tournamentId: s.id,
                tournamentName: s.name,
                format: s.format,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 8),
      if (d.myTeam != null)
        const SizedBox.shrink()
      else if (d.canCreateTeam) ...[
        GhButton(label: 'Criar equipa', onPressed: () => _createTeam(d)),
        const SizedBox(height: 8),
        const Text(
          'Ou toca numa equipa da lista para ver os jogadores e pedir para entrar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ] else
        GhBanner.error(TournamentLabels.ineligible(
          d.ineligibleReason,
          minAge: s.minAge,
          maxAge: s.maxAge,
        )),
    ];
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
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 15, height: 1.3)),
        ],
      ),
    );
  }
}

/// Atalho para o lobby da equipa do utilizador, no topo do torneio.
class _MyTeamCard extends StatelessWidget {
  const _MyTeamCard({required this.team, required this.maxPlayers, required this.onTap});

  final MyTeamBrief team;
  final int maxPlayers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final members = maxPlayers > 0 ? '${team.membersCount}/$maxPlayers jogadores' : '${team.membersCount} jogadores';
    return Semantics(
      button: true,
      label: 'A tua equipa ${team.name}, $members. Abrir lobby.',
      child: Material(
        color: GhColors.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GhColors.primary, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: team.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('A tua equipa',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(team.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(
                          [members, if (team.isHost) 'Líder', team.confirmed ? 'Confirmada' : 'Por confirmar'].join(' · '),
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
