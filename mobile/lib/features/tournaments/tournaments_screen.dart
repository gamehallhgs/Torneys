import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../geo/geo_models.dart';
import '../geo/location_picker.dart';
import '../teams/pending_section.dart';
import '../teams/team_lobby_screen.dart';
import '../teams/team_models.dart';
import '../teams/teams_repository.dart';
import 'tournament_card.dart';
import 'tournament_detail_screen.dart';
import 'tournament_models.dart';
import 'tournaments_repository.dart';

/// Página principal: torneios abertos / a decorrer / terminados, com filtro por datas e modalidade.
class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  static const _tabs = <(String, String)>[
    ('open', 'Abertos'),
    ('ongoing', 'A decorrer'),
    ('finished', 'Terminados'),
    ('mine', 'Os meus torneios'),
  ];
  /// "Todas" tem de ter um valor próprio: o PopupMenuButton do Flutter trata um item com valor null
  /// como "menu fechado sem escolher" e nunca chama onSelected (o bug de não conseguir voltar a "Todas").
  static const _sports = <String>[TournamentLabels.allSports, 'football7', 'football9', 'football11', 'futsal'];

  late TournamentsRepository _repo;
  late TeamsRepository _teams;
  late GeoRepository _geo;
  bool _started = false;

  String _status = 'open';
  String? _sport;
  LocationFilter _location = LocationFilter.none;
  DateTimeRange? _range;

  final List<TournamentSummary> _items = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  String? _error;

  // "Os meus torneios": convites recebidos e pedidos enviados.
  List<MyInvolvement> _invites = const [];
  List<MyInvolvement> _requests = const [];
  bool _acting = false;
  String? _actionError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final api = AuthScope.of(context).api;
      _repo = TournamentsRepository(api);
      _teams = TeamsRepository(api);
      _geo = GeoRepository(api);
      _load(reset: true);
    }
  }

  /// Cada recarga (mudança de filtro) incrementa a "geração"; respostas de gerações antigas são ignoradas.
  int _generation = 0;

  Future<void> _load({required bool reset}) async {
    if (_loading && !reset) {
      return;
    }
    final generation = reset ? ++_generation : _generation;
    final requestedPage = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _total = 0;
        _page = 1;
      }
    });
    try {
      final result = await _repo.list(
        status: _status,
        sport: _sport,
        district: _location.district,
        municipality: _location.municipality,
        from: _range?.start,
        to: _range?.end,
        page: requestedPage,
      );
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _page = result.page;
        _loading = false;
      });
      if (reset && _status == 'mine') {
        await _loadInvolvements(generation);
      }
    } catch (e) {
      debugPrint('[GameHall] lista de torneios falhou: $e');
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  /// Falhas aqui não escondem a lista de torneios: só ficam no log.
  Future<void> _loadInvolvements(int generation) async {
    try {
      final invites = await _teams.myInvites();
      final requests = await _teams.myRequests();
      if (mounted && generation == _generation) {
        setState(() {
          _invites = invites;
          _requests = requests;
        });
      }
    } catch (e, st) {
      debugPrint('[GameHall] convites/pedidos falharam: $e\n$st');
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_acting) {
      return;
    }
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (e, st) {
      debugPrint('[GameHall] ação falhou: $e\n$st');
      _actionError = friendlyError(e);
    }
    if (mounted) {
      await _load(reset: true);
      if (mounted) {
        setState(() => _acting = false);
      }
    }
  }

  Future<void> _openTeam(String teamId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TeamLobbyScreen(teamId: teamId)),
    );
    if (mounted) {
      await _load(reset: true);
    }
  }

  void _changeStatus(String status) {
    if (status == _status) {
      return;
    }
    setState(() {
      _status = status;
      _invites = const [];
      _requests = const [];
      _actionError = null;
    });
    _load(reset: true);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _range,
      helpText: 'Filtrar por datas',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load(reset: true);
    }
  }

  void _clearRange() {
    setState(() => _range = null);
    _load(reset: true);
  }

  void _changeSport(String value) {
    final sport = TournamentLabels.sportFilter(value);
    if (sport == _sport) {
      return;
    }
    setState(() => _sport = sport);
    _load(reset: true);
  }

  Future<void> _pickLocation() async {
    final picked = await pickLocation(context, geo: _geo, current: _location);
    if (picked != null && picked != _location && mounted) {
      setState(() => _location = picked);
      _load(reset: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _range = null;
      _sport = null;
      _location = LocationFilter.none;
    });
    _load(reset: true);
  }

  bool get _hasFilters => _range != null || _sport != null || _location.isActive;

  void _open(TournamentSummary t) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TournamentDetailScreen(tournamentId: t.id, initialName: t.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _items.length < _total;
    return RefreshIndicator(
      onRefresh: () async {
        await _load(reset: true);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tab in _tabs) ...[
                  ChoiceChip(
                    label: Text(tab.$2),
                    selected: _status == tab.$1,
                    onSelected: (_) => _changeStatus(tab.$1),
                    selectedColor: GhColors.primary,
                    backgroundColor: GhColors.fieldFill,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    side: const BorderSide(color: GhColors.fieldBorder),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _range == null
                        ? 'Datas'
                        : Fmt.dateRange(_range!.start, _range!.end),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: GhColors.fieldBorder),
                  ),
                ),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Limpar datas',
                  onPressed: _clearRange,
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Modalidade',
                initialValue: _sport ?? TournamentLabels.allSports,
                onSelected: _changeSport,
                itemBuilder: (_) => [
                  for (final s in _sports)
                    PopupMenuItem<String>(
                      value: s,
                      child: Text(s == TournamentLabels.allSports ? 'Todas as modalidades' : TournamentLabels.sport(s)),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: GhColors.fieldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports_soccer, size: 18),
                      const SizedBox(width: 6),
                      Text(_sport == null ? 'Todas' : TournamentLabels.sport(_sport!)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_location.label, overflow: TextOverflow.ellipsis),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: _location.isActive ? GhColors.success : GhColors.fieldBorder),
                  ),
                ),
              ),
              if (_location.isActive)
                IconButton(
                  tooltip: 'Limpar localidade',
                  onPressed: () {
                    setState(() => _location = LocationFilter.none);
                    _load(reset: true);
                  },
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_actionError != null) GhBanner.error(_actionError!),
          if (_status == 'mine')
            PendingSection(
              invites: _invites,
              requests: _requests,
              busy: _acting,
              onOpen: _openTeam,
              onAccept: (id) => _act(() => _teams.acceptInvite(id)),
              onDecline: (id) => _act(() => _teams.declineInvite(id)),
              onCancelRequest: (id) => _act(() => _teams.cancelRequest(id)),
            ),
          if (_error != null) ...[
            GhBanner.error(_error!),
            GhButton(label: 'Tentar novamente', onPressed: () => _load(reset: _items.isEmpty)),
          ] else if (_items.isEmpty && _loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    _status == 'mine' && !_hasFilters
                        ? 'Ainda não estás em nenhuma equipa. Abre um torneio para criar uma equipa ou pedir para entrar numa.'
                        : 'Não há torneios com estes filtros.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (_hasFilters)
                    TextButton(onPressed: _clearFilters, child: const Text('Limpar filtros')),
                ],
              ),
            )
          else ...[
            for (final t in _items) TournamentCard(tournament: t, onTap: () => _open(t)),
            if (hasMore)
              GhButton(
                label: 'Ver mais',
                secondary: true,
                loading: _loading,
                onPressed: () => _load(reset: false),
              ),
          ],
        ],
      ),
    );
  }
}
