import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Fundo em gradiente igual ao do Figma.
class GhBackground extends StatelessWidget {
  const GhBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: GhColors.background),
      child: child,
    );
  }
}

/// Logótipo. Usa assets/images/logo.png se existir; senão mostra texto.
class GhLogo extends StatelessWidget {
  const GhLogo({super.key, this.height = 90});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GAME HALL',
            style: TextStyle(
              fontSize: height * 0.4,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          Text(
            'TORNEIOS',
            style: TextStyle(
              fontSize: height * 0.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// Estrutura comum dos ecrãs: fundo, barra transparente, conteúdo centrado e com scroll.
class GhPage extends StatelessWidget {
  const GhPage({
    super.key,
    required this.children,
    this.title,
    this.showBack = true,
    this.actions,
  });

  final List<Widget> children;
  final String? title;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: showBack,
        title: title == null
            ? null
            : Text(title!, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: actions,
      ),
      body: GhBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão em forma de pílula: primário (#3460FF com contorno) ou secundário (cinzento).
class GhButton extends StatelessWidget {
  const GhButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.danger = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(secondary ? 20 : 999);
    final color = danger
        ? GhColors.danger
        : (secondary ? GhColors.secondary : GhColors.primary);

    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: radius,
          border: secondary ? null : Border.all(color: GhColors.border, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 52,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Link de texto simples.
class GhLink extends StatelessWidget {
  const GhLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white70,
        ),
      ),
    );
  }
}

/// Campo de texto com o estilo da app.
class GhTextField extends StatelessWidget {
  const GhTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.maxLength,
    this.onSubmitted,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        maxLength: maxLength,
        onFieldSubmitted: onSubmitted,
        readOnly: readOnly,
        onTap: onTap,
        enabled: enabled,
        autocorrect: false,
        enableSuggestions: !obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          filled: true,
          fillColor: GhColors.fieldFill,
          suffixIcon: suffix,
          labelStyle: const TextStyle(color: Colors.white70),
          errorStyle: const TextStyle(color: GhColors.error),
          enabledBorder: border(GhColors.fieldBorder),
          disabledBorder: border(GhColors.fieldBorder),
          focusedBorder: border(Colors.white, 2),
          errorBorder: border(GhColors.error),
          focusedErrorBorder: border(GhColors.error, 2),
        ),
      ),
    );
  }
}

/// Mensagem de erro ou de sucesso por cima dos formulários.
class GhBanner extends StatelessWidget {
  const GhBanner.error(this.message, {super.key}) : success = false;
  const GhBanner.success(this.message, {super.key}) : success = true;

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? GhColors.success : GhColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

/// Caixa de seleção com texto (os termos NUNCA vêm pré-marcados).
class GhCheckRow extends StatelessWidget {
  const GhCheckRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.linkLabel,
    required this.onOpen,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String linkLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          side: const BorderSide(color: Colors.white70, width: 1.5),
          activeColor: GhColors.primary,
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('$label '),
              GestureDetector(
                onTap: onOpen,
                child: Text(
                  linkLabel,
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
