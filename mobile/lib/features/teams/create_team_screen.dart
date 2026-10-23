import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../widgets/gh_widgets.dart';
import 'team_lobby_screen.dart';
import 'team_models.dart';
import 'teams_repository.dart';

/// Criar equipa: nome e cor (únicos no torneio). Quem cria fica como líder.
class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.takenColors,
  });

  final String tournamentId;
  final String tournamentName;

  /// Cores (#RRGGBB) já usadas por outras equipas do torneio.
  final List<String> takenColors;

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _color;
  bool _loading = false;
  String? _error;

  late final Set<String> _taken =
      widget.takenColors.map((c) => c.toUpperCase()).toSet();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final value = (v ?? '').trim();
    if (value.length < 3 || value.length > 30) {
      return 'O nome tem de ter entre 3 e 30 caracteres.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_color == null) {
      setState(() => _error = 'Escolhe a cor da equipa.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = TeamsRepository(AuthScope.of(context).api);
      final lobby = await repo.createTeam(widget.tournamentId, _name.text.trim(), _color!);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => TeamLobbyScreen(teamId: lobby.id)),
      );
    } catch (e, st) {
      debugPrint('[GameHall] criar equipa falhou: $e\n$st');
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GhPage(
      title: 'Criar equipa',
      children: [
        Text(widget.tournamentName,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),
        if (_error != null) GhBanner.error(_error!),
        Form(
          key: _formKey,
          child: GhTextField(
            controller: _name,
            label: 'Nome da equipa',
            maxLength: 30,
            validator: _validateName,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const Text('Cor da equipa', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          'Cada equipa tem uma cor própria no torneio. As cores já usadas estão indisponíveis.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in TeamLabels.palette)
              _ColorDot(
                hex: hex,
                selected: _color == hex,
                taken: _taken.contains(hex.toUpperCase()),
                onTap: () => setState(() => _color = hex),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Ficas como líder da equipa: aceitas pedidos, convidas jogadores e podes passar a liderança a outro jogador.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 16),
        GhButton(label: 'Criar equipa', loading: _loading, onPressed: _submit),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.taken,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final bool taken;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: !taken,
      label: taken ? 'Cor $hex indisponível' : 'Cor $hex',
      child: GestureDetector(
        onTap: taken ? null : onTap,
        child: Opacity(
          opacity: taken ? 0.25 : 1,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorFromHex(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.white38,
                width: selected ? 3 : 1,
              ),
            ),
            child: taken
                ? const Icon(Icons.block, color: Colors.white, size: 20)
                : selected
                    ? Icon(
                        Icons.check,
                        size: 22,
                        color: colorFromHex(hex).computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
          ),
        ),
      ),
    );
  }
}
