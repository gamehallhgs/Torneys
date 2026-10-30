import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import '../../widgets/skeleton.dart';
import '../geo/geo_models.dart';
import '../geo/location_picker.dart';
import '../notifications/notification_bell.dart';
import '../teams/pending_section.dart';
import '../teams/join_by_code_screen.dart';
import '../teams/team_lobby_screen.dart';
import '../teams/team_models.dart';
import '../teams/teams_repository.dart';
import 'chip_tabs_row.dart';
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

  /// Dentro de "Os meus torneios": null = todos; senão open, ongoing ou finished.
  String? _mineScope;
  String? _sport;
  LocationFilter _location = LocationFilter.none;
  DateTimeRange? _range;

  final List<TournamentSummary> _items = [];
  int _total = 0;
  int _page = 1;
  bool _loading = false;
  String? _error;

  // "Os meus torneios": pedidos enviados. Os convites recebidos estão na central de notificações (sino).
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
        scope: _mineScope,
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

  /// Pedidos enviados. Falhas aqui não escondem a lista de torneios: só ficam no log.
  Future<void> _loadInvolvements(int generation) async {
    try {
      final requests = await _teams.myRequests();
      if (mounted && generation == _generation) {
        setState(() => _requests = requests);
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

  Future<void> _openCodeScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const JoinByCodeScreen()),
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
      _mineScope = null;
      _requests = const [];
      _actionError = null;
    });
    _load(reset: true);
  }

  void _changeMineScope(String? scope) {
    if (scope == _mineScope) {
      return;
    }
    setState(() => _mineScope = scope);
    _load(reset: true);
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

  void _clearFilters() {
    setState(() {
      _mineScope = null;
      _range = null;
      _sport = null;
      _location = LocationFilter.none;
    });
    _load(reset: true);
  }

  bool get _hasFilters => _mineScope != null || _range != null || _sport != null || _location.isActive;

  void _open(TournamentSummary t) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TournamentDetailScreen(tournamentId: t.id, initialName: t.name),
    ));
  }

  static const _mineScopes = <(String?, String)>[
    (null, 'Todos'),
    ('open', 'Em inscrição'),
    ('ongoing', 'A decorrer'),
    ('finished', 'Terminados'),
  ];

  String _mineScopeLabel(String code) => _mineScopes.firstWhere((s) => s.$1 == code).$2;

  int get _filterCount => (_mineScope != null ? 1 : 0) + (_range != null ? 1 : 0) + (_sport != null ? 1 : 0) + (_location.isActive ? 1 : 0);

  /// Um só botão "Filtros" (com o número de filtros ativos) e, por baixo, os filtros ativos como etiquetas
  /// que se removem com um toque.
  Widget _filtersBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _openFilters,
          icon: const Icon(Icons.tune, size: 18),
          label: Text(_filterCount == 0 ? 'Filtros' : 'Filtros ($_filterCount)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: _filterCount == 0 ? GhColors.fieldBorder : GhColors.success),
          ),
        ),
        if (_hasFilters)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_mineScope != null)
                  InputChip(
                    label: Text(_mineScopeLabel(_mineScope!)),
                    onDeleted: () => _changeMineScope(null),
                  ),
                if (_range != null)
                  InputChip(
                    label: Text(Fmt.dateRange(_range!.start, _range!.end)),
                    onDeleted: _clearRange,
                  ),
                if (_sport != null)
                  InputChip(
                    label: Text(TournamentLabels.sport(_sport!)),
                    onDeleted: () => _changeSport(TournamentLabels.allSports),
                  ),
                if (_location.isActive)
                  InputChip(
                    label: Text(_location.label),
                    onDeleted: () {
                      setState(() => _location = LocationFilter.none);
                      _load(reset: true);
                    },
                  ),
                ActionChip(label: const Text('Limpar tudo'), onPressed: _clearFilters),
              ],
            ),
          ),
      ],
    );
  }

  /// Folha de filtros: escolhes vários filtros ao mesmo tempo e só aplicas no fim, com "Selecionar".
  Future<void> _openFilters() async {
    var mineScope = _mineScope;
    var sport = _sport;
    var range = _range;
    var location = _location;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GhColors.surface,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (_status == 'mine') ...[
                  const Text('Estado (por omissão: todos, em inscrição primeiro)',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (code, label) in _mineScopes)
                        ChoiceChip(
                          label: Text(label),
                          selected: mineScope == code,
                          onSelected: (_) => setSheet(() => mineScope = code),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Modalidade', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _sports)
                      ChoiceChip(
                        label: Text(s == TournamentLabels.allSports ? 'Todas' : TournamentLabels.sport(s)),
                        selected: (sport ?? TournamentLabels.allSports) == s,
                        onSelected: (_) => setSheet(() => sport = TournamentLabels.sportFilter(s)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: const Text('Datas'),
                  subtitle: Text(range == null ? 'Qualquer data' : Fmt.dateRange(range!.start, range!.end)),
                  trailing: range == null
                      ? null
                      : IconButton(
                          tooltip: 'Limpar datas',
                          icon: const Icon(Icons.close),
                          onPressed: () => setSheet(() => range = null),
                        ),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: sheet,
                      firstDate: DateTime(now.year - 3),
                      lastDate: DateTime(now.year + 3),
                      initialDateRange: range,
                      helpText: 'Filtrar por datas',
                      saveText: 'Aplicar',
                    );
                    if (picked != null) {
                      setSheet(() => range = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Localidade'),
                  subtitle: Text(location.label),
                  trailing: location.isActive
                      ? IconButton(
                          tooltip: 'Limpar localidade',
                          icon: const Icon(Icons.close),
                          onPressed: () => setSheet(() => location = LocationFilter.none),
                        )
                      : null,
                  onTap: () async {
                    final picked = await pickLocation(sheet, geo: _geo, current: location);
                    if (picked != null) {
                      setSheet(() => location = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                GhButton(label: 'Selecionar', onPressed: () => Navigator.of(sheet).pop(true)),
                TextButton(
                  onPressed: () => setSheet(() {
                    mineScope = null;
                    sport = null;
                    range = null;
                    location = LocationFilter.none;
                  }),
                  child: const Text('Limpar tudo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (apply == true && mounted) {
      setState(() {
        _mineScope = mineScope;
        _sport = sport;
        _range = range;
        _location = location;
      });
      await _load(reset: true);
    }
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
          ChipTabsRow(
            tabs: _tabs,
            selected: _status,
            onSelected: _changeStatus,
            // Central de notificações (convites para equipas), com pontinho vermelho quando há novas.
            trailing: NotificationBell(onReturn: () => _load(reset: true)),
          ),
          const SizedBox(height: 8),
          _filtersBar(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openCodeScreen,
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: const Text('Tenho um código'),
            ),
          ),
          const SizedBox(height: 8),
          if (_actionError != null) GhBanner.error(_actionError!),
          if (_status == 'mine')
            PendingSection(
              requests: _requests,
              busy: _acting,
              onOpen: _openTeam,
              onCancelRequest: (id) => _act(() => _teams.cancelRequest(id)),
            ),
          if (_error != null) ...[
            GhBanner.error(_error!),
            GhButton(label: 'Tentar novamente', onPressed: () => _load(reset: _items.isEmpty)),
          ] else if (_items.isEmpty && _loading)
            const SkeletonList()
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
