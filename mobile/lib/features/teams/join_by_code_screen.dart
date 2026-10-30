import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/theme.dart';
import '../../widgets/gh_widgets.dart';
import 'team_lobby_screen.dart';
import 'team_models.dart';
import 'teams_repository.dart';

/// "Tenho um código": escreve o GH-XXXX, vê a equipa e confirma a entrada.
class JoinByCodeScreen extends StatefulWidget {
  const JoinByCodeScreen({super.key});

  @override
  State<JoinByCodeScreen> createState() => _JoinByCodeScreenState();
}

class _JoinByCodeScreenState extends State<JoinByCodeScreen> {
  final _code = TextEditingController();
  late TeamsRepository _repo;
  var _ready = false;
  var _busy = false;
  String? _error;
  CodePreview? _preview;
  String? _requestSent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _repo = TeamsRepository(AuthScope.of(context).api);
      _ready = true;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final text = _code.text.trim();
    if (text.isEmpty || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
    });
    try {
      final p = await _repo.previewCode(text);
      if (mounted) {
        setState(() => _preview = p);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await _repo.joinByCode(_code.text.trim());
      if (!mounted) {
        return;
      }
      if (r.joined) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => TeamLobbyScreen(teamId: r.teamId)),
        );
        return;
      }
      setState(() {
        _requestSent = 'Pedido enviado. O líder vai decidir.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return GhPage(
      title: 'Tenho um código',
      children: [
        const Text(
          'Escreve o código que o líder da equipa te deu (por exemplo GH-7K3Q).',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        GhTextField(
          controller: _code,
          label: 'Código',
          maxLength: 8,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _lookup(),
          onChanged: (_) {
            if (_preview != null || _error != null || _requestSent != null) {
              setState(() {
                _preview = null;
                _error = null;
                _requestSent = null;
              });
            }
          },
        ),
        if (_error != null) GhBanner.error(_error!),
        if (_requestSent != null) GhBanner.success(_requestSent!),
        if (p == null)
          GhButton(label: 'Ver equipa', loading: _busy, onPressed: _lookup)
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: GhColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: p.color, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.teamName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(p.tournamentName, style: const TextStyle(color: Colors.white60)),
                      Text('${p.membersCount}/${p.maxPlayers} jogadores',
                          style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GhButton(
            label: 'Ver o lobby da equipa',
            secondary: true,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => TeamLobbyScreen(teamId: p.teamId)),
            ),
          ),
          const SizedBox(height: 12),
          if (p.blockedMessage != null)
            GhBanner.error(p.blockedMessage!)
          else if (_requestSent == null) ...[
            Text(
              p.directEntry
                  ? 'Ao confirmar, entras logo na equipa.'
                  : 'Esta equipa pede aprovação: vai ser enviado um pedido ao líder.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            GhButton(
              label: p.directEntry ? 'Entrar na equipa' : 'Pedir para entrar',
              loading: _busy,
              onPressed: _join,
            ),
          ],
        ],
      ],
    );
  }
}
