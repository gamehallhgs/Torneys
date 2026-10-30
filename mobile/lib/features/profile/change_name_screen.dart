import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';

/// Mudar o nome que aparece aos outros jogadores. Sem limite de mudanças.
class ChangeNameScreen extends StatefulWidget {
  const ChangeNameScreen({super.key});

  @override
  State<ChangeNameScreen> createState() => _ChangeNameScreenState();
}

class _ChangeNameScreenState extends State<ChangeNameScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _busy = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _name = TextEditingController(text: AuthScope.of(context).user?.displayName ?? '');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    final auth = AuthScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.changeName(_name.text);
      messenger.showSnackBar(const SnackBar(content: Text('Nome alterado.')));
      navigator.pop();
    } catch (e, st) {
      debugPrint('[GameHall] mudar nome falhou: $e\n$st');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GhPage(
      title: 'Mudar nome',
      children: [
        if (_error != null) GhBanner.error(_error!),
        const Text(
          'Este é o nome que aparece aos outros jogadores. Podes mudá-lo sempre que quiseres; '
          'o username e a tag não mudam.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              GhTextField(
                controller: _name,
                label: 'Nome',
                textInputAction: TextInputAction.done,
                validator: Validators.displayName,
              ),
              GhButton(label: 'Guardar', loading: _busy, onPressed: _save),
            ],
          ),
        ),
      ],
    );
  }
}
