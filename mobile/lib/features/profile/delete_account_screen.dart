import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';

/// Eliminação de conta (exigida pela Apple e pelo RGPD): pede a palavra-passe e confirma.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar conta?'),
        content: const Text(
          'Esta ação é permanente. Os teus dados pessoais serão anonimizados e não será possível recuperar a conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final auth = AuthScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.deleteAccount(_password.text);
      navigator.popUntil((route) => route.isFirst);
    } catch (e, st) {
      debugPrint('[GameHall] erro: $e\n$st');
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
      title: 'Eliminar conta',
      children: [
        const Text(
          'Ao eliminar a conta, os teus dados pessoais são anonimizados e a sessão é terminada em todos os dispositivos. '
          'Para confirmar, introduz a tua palavra-passe.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_error != null) GhBanner.error(_error!),
        Form(
          key: _formKey,
          child: GhTextField(
            controller: _password,
            label: 'Palavra-passe',
            obscure: true,
            textInputAction: TextInputAction.done,
            validator: Validators.requiredPassword,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 4),
        GhButton(
          label: 'Eliminar a minha conta',
          danger: true,
          loading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
