import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';
import 'username_check.dart';

/// Mudar o username: 1 vez por mês (a tag mantém-se). O antigo fica reservado 30 dias.
class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
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
      await auth.changeUsername(Validators.normalizeUsername(_username.text));
      messenger.showSnackBar(const SnackBar(content: Text('Username alterado.')));
      navigator.pop();
    } catch (e, st) {
      debugPrint('[GameHall] mudar username falhou: $e\n$st');
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
    final auth = AuthScope.of(context);
    final user = auth.user;
    final canChange = user?.canChangeUsername() ?? true;
    return GhPage(
      title: 'Mudar username',
      children: [
        if (_error != null) GhBanner.error(_error!),
        Text(
          'Agora és ${user?.handle ?? ''}.',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Só podes mudar o username uma vez por mês. A tua tag (os 3 algarismos a seguir ao #) não muda, por isso quem a tem guardada '
          'continua a conseguir convidar-te. O username antigo fica reservado durante 30 dias.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (!canChange)
          GhBanner.error(
            'Já mudaste o username este mês. Podes mudar de novo a '
            '${_fmt(user!.usernameNextChangeAt!)}.',
          )
        else
          Form(
            key: _formKey,
            child: Column(
              children: [
                UsernameField(
                  controller: _username,
                  label: 'Novo username',
                  currentUsername: user?.username,
                  check: usernameCheckerFor(auth.api),
                ),
                GhButton(label: 'Guardar', loading: _busy, onPressed: _save),
              ],
            ),
          ),
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
