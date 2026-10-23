import 'package:flutter/material.dart';

/// Cores tiradas do Figma (ecrã Home): botões #3460FF com contorno #D4D4D4,
/// botões secundários #6F6F6F, texto branco, fundo em gradiente preto -> azul-violeta.
/// O gradiente é uma estimativa a partir do desenho: ajusta aqui se quiseres afinar.
class GhColors {
  GhColors._();

  static const Color primary = Color(0xFF3460FF);
  static const Color border = Color(0xFFD4D4D4);
  static const Color secondary = Color(0xFF6F6F6F);
  static const Color danger = Color(0xFFB3261E);

  /// Laranja da etiqueta "Cheio" (combina com o azul/violeta do tema).
  static const Color full = Color(0xFFFF9F43);

  static const Color fieldFill = Color(0x1AFFFFFF);
  static const Color fieldBorder = Color(0x66FFFFFF);
  static const Color error = Color(0xFFFF8A8A);
  static const Color success = Color(0xFF6EE7A0);
  static const Color surface = Color(0xFF16165F);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF020208), Color(0xFF14145C), Color(0xFF2F2BBA)],
    stops: [0.0, 0.55, 1.0],
  );
}

class GhTheme {
  GhTheme._();

  static ThemeData get dark {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: GhColors.primary,
        onPrimary: Colors.white,
        secondary: GhColors.secondary,
        surface: GhColors.surface,
        onSurface: Colors.white,
        error: GhColors.error,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
