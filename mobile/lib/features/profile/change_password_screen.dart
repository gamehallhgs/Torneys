import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../core/validators.dart';
import '../../widgets/gh_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    final auth = AuthScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await auth.changePassword(_current.text, _next.text);
      if (mounted) {
        _current.clear();
        _next.clear();
        _confirm.clear();
        setState(() {
          _busy = false;
          _success = 'Palavra-passe alterada. As outras sessões foram terminadas.';
        });
      }
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
    final toggle = IconButton(
      icon: Icon(_show ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
      onPressed: () => setState(() => _show = !_show),
    );
    return GhPage(
      title: 'Alterar palavra-passe',
      children: [
        if (_error != null) GhBanner.error(_error!),
        if (_success != null) GhBanner.success(_success!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              GhTextField(
                controller: _current,
                label: 'Palavra-passe atual',
                obscure: !_show,
                textInputAction: TextInputAction.next,
                validator: Validators.requiredPassword,
                suffix: toggle,
              ),
              GhTextField(
                controller: _next,
                label: 'Nova palavra-passe (mín. ${Validators.minPasswordLength})',
                obscure: !_show,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: Validators.newPassword,
              ),
              GhTextField(
                controller: _confirm,
                label: 'Repetir nova palavra-passe',
                obscure: !_show,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmPassword(v, _next.text),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        GhButton(label: 'Guardar', onPressed: _submit, loading: _busy),
      ],
    );
  }
}
