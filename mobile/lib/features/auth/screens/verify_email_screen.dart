import 'package:flutter/material.dart';

import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/validators.dart';
import '../../../widgets/gh_widgets.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    final auth = AuthScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await auth.verifyEmail(widget.email, _code.text);
      if (!mounted) {
        return;
      }
      navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          initialEmail: widget.email,
          notice: 'Email verificado! Já podes iniciar sessão.',
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

  Future<void> _resend() async {
    if (_resending) {
      return;
    }
    final auth = AuthScope.of(context);
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await auth.resendVerification(widget.email);
      if (mounted) {
        setState(() {
          _resending = false;
          _info = 'Se o email existir, enviámos um novo código.';
        });
      }
    } catch (e, st) {
      debugPrint('[GameHall] erro: $e\n$st');
      if (mounted) {
        setState(() {
          _resending = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GhPage(
      title: 'Verificar email',
      children: [
        Text(
          'Enviámos um código de 6 dígitos para ${widget.email}. '
          'Introduz-o abaixo (é válido durante 15 minutos).',
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_error != null) GhBanner.error(_error!),
        if (_info != null) GhBanner.success(_info!),
        Form(
          key: _formKey,
          child: GhTextField(
            controller: _code,
            label: 'Código',
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            validator: Validators.code,
            onSubmitted: (_) => _verify(),
          ),
        ),
        const SizedBox(height: 4),
        GhButton(label: 'Verificar', onPressed: _verify, loading: _busy),
        const SizedBox(height: 8),
        GhLink(
          label: _resending ? 'A enviar...' : 'Reenviar código',
          onPressed: _resending ? null : _resend,
        ),
      ],
    );
  }
}
