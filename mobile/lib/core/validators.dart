/// Validações do lado da app (feedback imediato). O servidor valida sempre de novo:
/// estas regras espelham as dele mas nunca as substituem.
class Validators {
  Validators._();

  static const int minPasswordLength = 12;
  static const int maxPasswordLength = 128;
  static const int minimumAge = 13;

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Indica o teu email.';
    }
    if (text.length > 254 || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Email inválido.';
    }
    return null;
  }

  /// "  @Hugo " -> "hugo" (igual ao servidor).
  static String normalizeUsername(String? value) {
    var s = (value ?? '').trim();
    if (s.startsWith('@')) {
      s = s.substring(1);
    }
    return s.toLowerCase();
  }

  static final RegExp _usernameShape = RegExp(r'^[a-z0-9][a-z0-9._]{1,18}[a-z0-9]$');

  /// Username: 3 a 20 caracteres, minúsculas, números, "." e "_"; sem começar/acabar em "." ou "_" nem ".." seguidos.
  /// (Nomes reservados e usernames já usados só o servidor sabe.)
  static String? username(String? value) {
    final s = normalizeUsername(value);
    if (s.isEmpty) {
      return 'Escolhe um username.';
    }
    if (s.length < 3 || s.length > 20) {
      return 'O username deve ter entre 3 e 20 caracteres.';
    }
    if (s.contains('..')) {
      return 'Não uses dois pontos seguidos.';
    }
    if (!_usernameShape.hasMatch(s)) {
      return 'Usa só letras minúsculas, números, "." e "_", e não comeces nem acabes com "." ou "_".';
    }
    return null;
  }

  static final RegExp _handleShape = RegExp(r'^@?([^#\s]+)\s*#\s*(\d{3})$');

  /// "hugo#482" / "@Hugo#482" -> (username, tag); null se não tiver o formato certo (a tag é obrigatória).
  static ({String username, String tag})? parseHandle(String? value) {
    final m = _handleShape.firstMatch((value ?? '').trim());
    if (m == null) {
      return null;
    }
    final name = normalizeUsername(m.group(1));
    if (username(name) != null) {
      return null;
    }
    return (username: name, tag: m.group(2)!);
  }

  static String? displayName(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2 || text.length > 40) {
      return 'O nome deve ter entre 2 e 40 caracteres.';
    }
    return null;
  }

  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Indica a palavra-passe.';
    }
    return null;
  }

  static String? newPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Indica uma palavra-passe.';
    }
    if (text.length < minPasswordLength) {
      return 'A palavra-passe deve ter pelo menos $minPasswordLength caracteres.';
    }
    if (text.length > maxPasswordLength) {
      return 'A palavra-passe não pode ter mais de $maxPasswordLength caracteres.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '') != original) {
      return 'As palavras-passe não coincidem.';
    }
    return null;
  }

  static String? code(String? value) {
    final text = (value ?? '').trim();
    if (!RegExp(r'^\d{6}$').hasMatch(text)) {
      return 'O código tem 6 dígitos.';
    }
    return null;
  }

  /// Idade completa em anos numa data de referência.
  static int ageOn(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    final hadBirthday = today.month > birthDate.month ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) {
      age--;
    }
    return age;
  }

  static String? birthDate(DateTime? value, {DateTime? today}) {
    if (value == null) {
      return 'Indica a tua data de nascimento.';
    }
    final now = today ?? DateTime.now();
    if (value.isAfter(now)) {
      return 'Data de nascimento inválida.';
    }
    final age = ageOn(value, now);
    if (age > 120) {
      return 'Data de nascimento inválida.';
    }
    if (age < minimumAge) {
      return 'Tens de ter pelo menos $minimumAge anos para criar conta.';
    }
    return null;
  }

  /// 05/03/2008
  static String formatDatePt(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year.toString().padLeft(4, '0')}';
  }

  /// 2008-03-05 (formato que a API espera)
  static String formatDateApi(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$m-$d';
  }
}
