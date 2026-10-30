import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import 'team_models.dart';
import 'teams_repository.dart';

/// Formação estilo FIFA: o campo com os lugares da formação e o banco de suplentes.
/// Todos os jogadores veem; só o líder muda (toca num lugar para escolher quem joga lá).
class LineupScreen extends StatefulWidget {
  const LineupScreen({super.key, required this.lobby});

  final TeamLobby lobby;

  @override
  State<LineupScreen> createState() => _LineupScreenState();
}

class _LineupScreenState extends State<LineupScreen> {
  late TeamsRepository _repo;
  bool _started = false;
  late String _formation;
  late Map<int, String> _bySlot; // lugar -> userId
  bool _busy = false;
  String? _error;

  TeamLobby get _l => widget.lobby;
  bool get _canEdit => _l.isHost;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = TeamsRepository(AuthScope.of(context).api);
      _formation = _l.lineup.formation;
      _bySlot = {
        for (final m in _l.members)
          if (m.slot != null) m.slot!: m.userId,
      };
    }
  }

  TeamMember? _member(String? userId) {
    for (final m in _l.members) {
      if (m.userId == userId) {
        return m;
      }
    }
    return null;
  }

  Set<String> get _onPitch => _bySlot.values.toSet();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.setLineup(_l.id, _formation, {for (final e in _bySlot.entries) e.value: e.key});
    } catch (e, st) {
      debugPrint('[GameHall] formação falhou: $e\n$st');
      _error = friendlyError(e);
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _changeFormation(String f) async {
    if (f == _formation || _busy) {
      return;
    }
    // Ao mudar de formação o número de lugares pode ser outro: mantém quem cabe no mesmo lugar.
    final count = Lineup.layout(f).length;
    setState(() {
      _formation = f;
      _bySlot.removeWhere((slot, _) => slot >= count);
    });
    await _save();
  }

  Future<void> _pickForSlot(int slot) async {
    if (!_canEdit || _busy) {
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: GhColors.surface,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(slot == 0 ? 'Guarda-redes' : 'Lugar $slot')),
            for (final m in _l.members)
              ListTile(
                leading: Icon(_bySlot[slot] == m.userId ? Icons.check_circle : Icons.person_outline),
                title: Text(m.displayName),
                subtitle: Text(
                  [
                    if (m.position != null) TeamLabels.position(m.position!),
                    _onPitch.contains(m.userId) && _bySlot[slot] != m.userId ? 'troca de lugar' : 'suplente',
                  ].join(' · '),
                ),
                onTap: () => Navigator.of(sheet).pop(m.userId),
              ),
            if (_bySlot[slot] != null)
              ListTile(
                leading: const Icon(Icons.event_seat_outlined),
                title: const Text('Passar para o banco'),
                onTap: () => Navigator.of(sheet).pop(''),
              ),
          ],
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    setState(() {
      if (choice.isEmpty) {
        _bySlot.remove(slot);
      } else {
        final previous = _bySlot[slot];
        final fromSlot = _bySlot.entries.where((e) => e.value == choice).map((e) => e.key).firstOrNull;
        _bySlot[slot] = choice;
        if (fromSlot != null) {
          // Troca: quem estava neste lugar vai para o lugar do escolhido (ou para o banco).
          if (previous != null) {
            _bySlot[fromSlot] = previous;
          } else {
            _bySlot.remove(fromSlot);
          }
        }
      }
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final bench = _l.members.where((m) => !_onPitch.contains(m.userId)).toList();
    return GhPage(
      title: 'Formação',
      children: [
        if (_error != null) GhBanner.error(_error!),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _l.lineup.formations)
              ChoiceChip(
                label: Text(f),
                selected: f == _formation,
                onSelected: _canEdit && !_busy ? (_) => _changeFormation(f) : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Pitch(
          formation: _formation,
          color: colorFromHex(_l.colorHex),
          nameAt: (slot) => _member(_bySlot[slot])?.displayName,
          positionAt: (slot) => _member(_bySlot[slot])?.position,
          onTapSlot: _canEdit ? _pickForSlot : null,
        ),
        const SizedBox(height: 12),
        Text(
          _canEdit
              ? 'Toca num lugar para escolher quem joga lá.'
              : 'Só o líder pode mudar a formação.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 16),
        const Text('Suplentes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (bench.isEmpty)
          const Text('Todos os jogadores estão em campo.', style: TextStyle(color: Colors.white60))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in bench)
                Chip(label: Text(m.position == null ? m.displayName : '${m.displayName} · ${m.position}')),
            ],
          ),
      ],
    );
  }
}

/// O campo (vertical, baliza da equipa em baixo) com um círculo por lugar.
class Pitch extends StatelessWidget {
  const Pitch({
    super.key,
    required this.formation,
    required this.color,
    required this.nameAt,
    this.positionAt,
    this.onTapSlot,
  });

  final String formation;
  final Color color;
  final String? Function(int slot) nameAt;

  /// Posição preferida do jogador (GK, ST...), mostrada ao lado do nome.
  final String? Function(int slot)? positionAt;
  final void Function(int slot)? onTapSlot;

  @override
  Widget build(BuildContext context) {
    final spots = Lineup.layout(formation);
    // A última linha da formação nunca chega a y = 1: esticamos o desenho para o grupo ficar centrado no campo todo
    // (a mesma margem em cima e em baixo).
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    double normY(double y) => maxY > 0 ? y / maxY : 0.5;
    return AspectRatio(
      aspectRatio: 0.78,
      child: LayoutBuilder(
        builder: (context, box) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B6B3A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white54, width: 2),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(height: 2, color: Colors.white24),
              ),
              for (var i = 0; i < spots.length; i++)
                Positioned(
                  left: spots[i].x * box.maxWidth - 36,
                  // y = 0 (guarda-redes) fica em baixo; 12 px de margem + altura do jogador (~72) em cima e em baixo.
                  top: (1 - normY(spots[i].y)) * (box.maxHeight - 24 - 72) + 12,
                  width: 72,
                  child: _SpotView(
                    key: ValueKey('spot-$i'),
                    color: color,
                    name: nameAt(i),
                    position: positionAt?.call(i),
                    onTap: onTapSlot == null ? null : () => onTapSlot!(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotView extends StatelessWidget {
  const _SpotView({super.key, required this.color, required this.name, this.position, this.onTap});

  final Color color;
  final String? name;
  final String? position;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: name == null ? Colors.black26 : color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(name == null ? Icons.add : Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          if (position != null)
            Text(position!, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}
