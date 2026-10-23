import 'package:flutter/material.dart';

import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/validators.dart';
import '../../../widgets/gh_widgets.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
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
      await auth.forgotPassword(_email.text);
      if (!mounted) {
        return;
      }
      navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ResetPasswordScreen(email: _email.text.trim()),
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
      title: 'Recuperar palavra-passe',
      children: [
        const Text(
          'Indica o teu email. Se existir uma conta, enviamos um código para definires uma nova palavra-passe.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_error != null) GhBanner.error(_error!),
        Form(
          key: _formKey,
          child: GhTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 4),
        GhButton(label: 'Enviar código', onPressed: _submit, loading: _busy),
      ],
    );
  }
}
