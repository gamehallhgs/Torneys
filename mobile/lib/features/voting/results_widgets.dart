import 'package:flutter/material.dart';

import '../../core/error_messages.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../teams/team_models.dart';
import 'voting_models.dart';
import 'voting_repository.dart';

/// Caixa com título, igual às secções da página do torneio.
class ResultsSection extends StatelessWidget {
  const ResultsSection({super.key, required this.title, required this.children});

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
      // Material transparente: os ListTile/ExpansionTile pintam o fundo no Material mais próximo.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Pódio das equipas vencedoras: 2.º, 1.º e 3.º (podem ser dois 3.º ex aequo).
class PodiumCard extends StatelessWidget {
  const PodiumCard({super.key, required this.podium});

  final List<PodiumEntry> podium;

  static const _gold = Color(0xFFFFC107);
  static const _silver = Color(0xFFB0BEC5);
  static const _bronze = Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    final byPlace = {
      for (final p in podium) p.place: [...podium.where((x) => x.place == p.place)],
    };
    final ordered = [...?byPlace[2], ...?byPlace[1], ...?byPlace[3]];
    return ResultsSection(
      title: 'Pódio',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (final e in ordered) Expanded(child: _step(e))],
        ),
      ],
    );
  }

  Widget _step(PodiumEntry e) {
    final color = switch (e.place) { 1 => _gold, 2 => _silver, _ => _bronze };
    final height = switch (e.place) { 1 => 84.0, 2 => 64.0, _ => 48.0 };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: color, size: e.place == 1 ? 34 : 26),
          const SizedBox(height: 4),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: e.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            e.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              border: Border.all(color: color),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Text('${e.place}.º', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

/// Melhor jogador e melhor guarda-redes lado a lado (só os que existem).
class AwardsRow extends StatelessWidget {
  const AwardsRow({super.key, required this.bestPlayer, required this.bestGoalkeeper});

  final Award? bestPlayer;
  final Award? bestGoalkeeper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _card(VotingLabels.bestPlayer, bestPlayer)),
          const SizedBox(width: 12),
          Expanded(child: _card(VotingLabels.bestGoalkeeper, bestGoalkeeper)),
        ],
      ),
    );
  }

  Widget _card(String category, Award? award) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: PodiumCard._gold, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  VotingLabels.category(category),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (award == null)
            const Text('Sem votação', style: TextStyle(color: Colors.white54, fontSize: 12))
          else if (award.isPending)
            const Text(
              'Empate: a aguardar desempate.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
            )
          else if (award.winners.isEmpty)
            const Text('Sem votos', style: TextStyle(color: Colors.white54, fontSize: 12))
          else
            for (final w in award.winners) _winner(w, shared: award.winners.length > 1),
        ],
      ),
    );
  }

  Widget _winner(AwardWinner w, {required bool shared}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(w.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: w.color, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(w.teamName,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          if (w.positionLabel != null)
            Text(w.positionLabel!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (shared)
            const Text('Co-vencedor (empate)', style: TextStyle(color: Colors.amber, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Votação aberta, na própria página do torneio: escolhe a categoria e o jogador (por equipas).
class VotingPanel extends StatefulWidget {
  const VotingPanel({super.key, required this.tournamentId, required this.voting, required this.repo, required this.onVoted});

  final String tournamentId;
  final Voting voting;
  final VotingRepository repo;

  /// Chamado depois de um voto guardado (para recarregar).
  final Future<void> Function() onVoted;

  @override
  State<VotingPanel> createState() => _VotingPanelState();
}

class _VotingPanelState extends State<VotingPanel> {
  late String _category;
  final _search = TextEditingController();
  var _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _category = widget.voting.categories.first.category;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  VotingCategory get _current => widget.voting.categories.firstWhere(
        (c) => c.category == _category,
        orElse: () => widget.voting.categories.first,
      );

  Future<void> _vote(VotingCandidate c) async {
    if (_busy || !widget.voting.canVote) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.repo.vote(widget.tournamentId, _category, c.userId);
      _info = 'Voto guardado em ${c.displayName}. Podes mudá-lo até a votação fechar.';
      await widget.onVoted();
    } catch (e) {
      debugPrint('[GameHall] voto falhou: $e');
      _error = friendlyError(e);
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.voting;
    final cat = _current;
    final query = _search.text.trim().toLowerCase();
    final teams = <String, List<VotingCandidate>>{};
    for (final c in cat.candidates) {
      if (query.isEmpty || c.displayName.toLowerCase().contains(query) || c.teamName.toLowerCase().contains(query)) {
        teams.putIfAbsent(c.teamId, () => []).add(c);
      }
    }
    return ResultsSection(
      title: v.isTiebreak ? 'Votação de desempate' : 'Votação aberta',
      children: [
        Text(
          v.isTiebreak
              ? 'Só estão a votos os jogadores que ficaram empatados. Fecha às ${Fmt.time(v.closesAt)}.'
              : 'Vota no melhor jogador e no melhor guarda-redes do torneio. Fecha às ${Fmt.time(v.closesAt)}.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (!v.canVote) GhBanner.error(VotingLabels.cannotVote(v.cannotVoteReason)),
        if (_error != null) GhBanner.error(_error!),
        if (_info != null) GhBanner.success(_info!),
        if (v.categories.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (final c in v.categories)
                ChoiceChip(
                  label: Text(VotingLabels.category(c.category)),
                  selected: c.category == _category,
                  onSelected: (_) => setState(() {
                    _category = c.category;
                    _info = null;
                  }),
                ),
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Procurar jogador ou equipa',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (teams.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Nenhum jogador encontrado.', style: TextStyle(color: Colors.white60)),
          ),
        for (final entry in teams.entries)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('${_category}_${entry.key}_${query.isEmpty}'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: query.isNotEmpty || cat.myVote != null && entry.value.any((c) => c.userId == cat.myVote),
              leading: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: entry.value.first.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white54),
                ),
              ),
              title: Text(entry.value.first.teamName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${entry.value.length} jogadores', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              children: [for (final c in entry.value) _candidate(c, cat.myVote == c.userId)],
            ),
          ),
      ],
    );
  }

  Widget _candidate(VotingCandidate c, bool chosen) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 28),
      enabled: widget.voting.canVote && !_busy,
      title: Text(c.displayName),
      subtitle: c.position == null ? null : Text(TeamLabels.position(c.position!), style: const TextStyle(fontSize: 12)),
      trailing: chosen
          ? const Icon(Icons.check_circle, color: GhColors.success)
          : const Icon(Icons.radio_button_unchecked, color: Colors.white38),
      onTap: () => _vote(c),
    );
  }
}
