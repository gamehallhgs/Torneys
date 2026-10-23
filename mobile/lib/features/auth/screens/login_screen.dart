import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/validators.dart';
import '../../../widgets/gh_widgets.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail, this.notice});

  final String? initialEmail;
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    final navigator = Navigator.of(context);
    final auth = AuthScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.login(_email.text, _password.text);
      // O ecrã raiz muda sozinho (Home ou aceitação de termos): fechamos as rotas empilhadas.
      navigator.popUntil((route) => route.isFirst);
    } catch (e, st) {
      debugPrint('[GameHall] erro: $e\n$st');
      if (!mounted) {
        return;
      }
      if (e is ApiException && e.code == 'email_not_verified') {
        navigator.push(MaterialPageRoute<void>(
          builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
        ));
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GhPage(
      title: 'Iniciar sessão',
      children: [
        if (widget.notice != null) GhBanner.success(widget.notice!),
        if (_error != null) GhBanner.error(_error!),
        Form(
          key: _formKey,
          child: Column(
            children: [
              GhTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              GhTextField(
                controller: _password,
                label: 'Palavra-passe',
                obscure: !_showPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                validator: Validators.requiredPassword,
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GhButton(label: 'Entrar', onPressed: _submit, loading: _busy),
        const SizedBox(height: 8),
        GhLink(
          label: 'Esqueci-me da palavra-passe',
          onPressed: _busy
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        ForgotPasswordScreen(initialEmail: _email.text.trim()),
                  )),
        ),
        GhLink(
          label: 'Ainda não tens conta? Criar conta',
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
                  ),
        ),
      ],
    );
  }
}
