import 'package:flutter/material.dart';

import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/validators.dart';
import '../../../widgets/gh_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    final auth = AuthScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.resetPassword(widget.email, _code.text, _password.text);
      if (!mounted) {
        return;
      }
      navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          initialEmail: widget.email,
          notice: 'Palavra-passe alterada. Inicia sessão com a nova palavra-passe.',
        ),
      ));
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
      title: 'Nova palavra-passe',
      children: [
        Text(
          'Introduz o código de 6 dígitos enviado para ${widget.email} e escolhe a nova palavra-passe.',
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_error != null) GhBanner.error(_error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              GhTextField(
                controller: _code,
                label: 'Código',
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.next,
                validator: Validators.code,
              ),
              GhTextField(
                controller: _password,
                label: 'Nova palavra-passe (mín. ${Validators.minPasswordLength})',
                obscure: !_showPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: Validators.newPassword,
                suffix: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              GhTextField(
                controller: _confirm,
                label: 'Repetir nova palavra-passe',
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmPassword(v, _password.text),
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
