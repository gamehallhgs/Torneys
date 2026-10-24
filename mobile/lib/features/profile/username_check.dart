import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';

/// Resposta de GET /api/v1/usernames/check.
class UsernameCheck {
  const UsernameCheck({required this.available, this.reason, this.message});

  final bool available;

  /// invalid, reserved, taken, recently_used
  final String? reason;
  final String? message;

  factory UsernameCheck.fromJson(Map<String, dynamic> j) => UsernameCheck(
        available: j['available'] == true,
        reason: j['reason'] as String?,
        message: j['message'] as String?,
      );
}

typedef UsernameChecker = Future<UsernameCheck> Function(String username);

/// Pergunta ao servidor se o username está livre (público: serve também no registo, antes de haver conta).
UsernameChecker usernameCheckerFor(ApiClient api) => (String username) async {
      final q = Uri.encodeQueryComponent(username);
      final res = (await api.get('/api/v1/usernames/check?username=$q', auth: true)).ensureOk();
      return UsernameCheck.fromJson(res.json);
    };

/// Campo de username com verificação de disponibilidade enquanto se escreve (espera 450 ms depois da última tecla).
/// [onAvailabilityChanged]: true = livre, false = não serve, null = por verificar.
class UsernameField extends StatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    required this.check,
    this.label = 'Username',
    this.onAvailabilityChanged,
    this.debounce = const Duration(milliseconds: 450),
    this.currentUsername,
  });

  final TextEditingController controller;
  final UsernameChecker check;
  final String label;
  final ValueChanged<bool?>? onAvailabilityChanged;
  final Duration debounce;

  /// O username que já é teu (escrevê-lo outra vez não conta como "em uso").
  final String? currentUsername;

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

enum _Phase { idle, checking, ok, bad }

class _UsernameFieldState extends State<UsernameField> {
  Timer? _timer;
  int _seq = 0;
  _Phase _phase = _Phase.idle;
  String? _message;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _set(_Phase phase, [String? message]) {
    setState(() {
      _phase = phase;
      _message = message;
    });
    widget.onAvailabilityChanged?.call(switch (phase) {
      _Phase.ok => true,
      _Phase.bad => false,
      _ => null,
    });
  }

  void _changed(String raw) {
    _timer?.cancel();
    final seq = ++_seq;
    final name = Validators.normalizeUsername(raw);
    if (name.isEmpty) {
      _set(_Phase.idle);
      return;
    }
    final local = Validators.username(name);
    if (local != null) {
      _set(_Phase.bad, local);
      return;
    }
    if (name == widget.currentUsername) {
      _set(_Phase.bad, 'Este já é o teu username.');
      return;
    }
    _set(_Phase.checking);
    _timer = Timer(widget.debounce, () async {
      try {
        final r = await widget.check(name);
        if (!mounted || seq != _seq) {
          return; // entretanto escreveu outra coisa
        }
        _set(r.available ? _Phase.ok : _Phase.bad, r.available ? null : (r.message ?? 'Este username não está disponível.'));
      } catch (e) {
        debugPrint('[GameHall] verificar username falhou: $e');
        if (mounted && seq == _seq) {
          // Sem rede: não bloqueamos; o servidor volta a validar ao guardar.
          _set(_Phase.idle);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (_phase) {
      _Phase.ok => (Icons.check_circle, GhColors.success, 'Disponível'),
      _Phase.bad => (Icons.cancel, GhColors.error, _message ?? ''),
      _Phase.checking => (Icons.hourglass_top, Colors.white60, 'A verificar...'),
      _Phase.idle => (null, Colors.white60, ''),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GhTextField(
          controller: widget.controller,
          label: widget.label,
          prefixText: '@',
          maxLength: 21,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newUsername],
          onChanged: _changed,
          validator: (v) {
            final local = Validators.username(v);
            if (local != null) {
              return local;
            }
            return _phase == _Phase.bad ? (_message ?? 'Este username não está disponível.') : null;
          },
        ),
        if (icon != null)
          Padding(
            key: const ValueKey('username-status'),
            padding: const EdgeInsets.only(left: 4, bottom: 12, top: 0),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
              ],
            ),
          ),
      ],
    );
  }
}
