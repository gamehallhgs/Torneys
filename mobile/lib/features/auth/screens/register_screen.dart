import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/models.dart';
import '../../../core/validators.dart';
import '../../../widgets/gh_widgets.dart';
import '../../profile/username_check.dart';
import 'legal_viewer_screen.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _birth = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  DateTime? _birthDate;
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  String? _legalError;
  LegalInfo? _legal;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadLegal();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _birth.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _loadLegal() async {
    try {
      final legal = await AuthScope.of(context).fetchLegalCurrent();
      if (mounted) {
        setState(() {
          _legal = legal;
          _legalError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _legalError = friendlyError(e));
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birth.text = Validators.formatDatePt(picked);
      });
    }
  }

  void _openLegal(String type) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalViewerScreen(type: type),
    ));
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final valid = _formKey.currentState!.validate();
    if (!valid) {
      return;
    }
    if (!_acceptTerms || !_acceptPrivacy) {
      setState(() => _error =
          'Tens de aceitar os Termos e Condições e a Política de Privacidade.');
      return;
    }
    final legal = _legal;
    if (legal == null) {
      setState(() => _error = 'Não foi possível obter os documentos legais.');
      return;
    }

    final auth = AuthScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.register(
        email: _email.text,
        password: _password.text,
        displayName: _name.text,
        username: Validators.normalizeUsername(_username.text),
        birthDateApi: Validators.formatDateApi(_birthDate!),
        legal: legal,
      );
      if (!mounted) {
        return;
      }
      navigator.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
      ));
    } catch (e, st) {
      debugPrint('[GameHall] erro: $e\n$st');
      if (!mounted) {
        return;
      }
      if (e is ApiException && e.code == 'legal_version_outdated') {
        // Voltamos a carregar as versões e pedimos nova confirmação.
        setState(() {
          _acceptTerms = false;
          _acceptPrivacy = false;
        });
        await _loadLegal();
      }
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
      title: 'Criar conta',
      children: [
        if (_error != null) GhBanner.error(_error!),
        if (_legalError != null) ...[
          GhBanner.error(_legalError!),
          GhButton(label: 'Tentar novamente', onPressed: _loadLegal, secondary: true),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              GhTextField(
                controller: _name,
                label: 'Nome',
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                maxLength: 40,
                helperText: 'É o nome que os outros jogadores veem.',
                validator: Validators.displayName,
              ),
              UsernameField(
                controller: _username,
                label: 'Username (único)',
                check: usernameCheckerFor(AuthScope.of(context).api),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14, left: 4),
                child: Text(
                  'Serve para te convidarem para equipas. Só letras minúsculas, números, "." e "_" (3 a 20). '
                  'Recebes também uma tag de 3 algarismos (ex.: #482) que não muda.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              GhTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              GhTextField(
                controller: _birth,
                label: 'Data de nascimento',
                readOnly: true,
                onTap: _pickBirthDate,
                suffix: const Icon(Icons.calendar_today, color: Colors.white70),
                validator: (_) => Validators.birthDate(_birthDate),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14, left: 4),
                child: Text(
                  'Tem de ser a tua data real. Não pode ser alterada depois.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              GhTextField(
                controller: _password,
                label: 'Palavra-passe (mín. ${Validators.minPasswordLength} caracteres)',
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
                label: 'Repetir palavra-passe',
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmPassword(v, _password.text),
              ),
            ],
          ),
        ),
        GhCheckRow(
          value: _acceptTerms,
          onChanged: (v) => setState(() => _acceptTerms = v),
          label: 'Li e aceito os',
          linkLabel: 'Termos e Condições',
          onOpen: () => _openLegal('terms'),
        ),
        GhCheckRow(
          value: _acceptPrivacy,
          onChanged: (v) => setState(() => _acceptPrivacy = v),
          label: 'Li e aceito a',
          linkLabel: 'Política de Privacidade',
          onOpen: () => _openLegal('privacy'),
        ),
        const SizedBox(height: 16),
        GhButton(
          label: 'Criar conta',
          loading: _busy,
          onPressed: _legal == null ? null : _submit,
        ),
      ],
    );
  }
}
