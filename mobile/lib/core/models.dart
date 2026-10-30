class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.emailVerified,
    required this.birthDate,
    this.username = '',
    this.usernameTag = '',
    this.usernameChangesLeft = 1,
    this.gender = 'other',
    this.onboardingSeen = true,
    this.pushEnabled = true,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool emailVerified;
  final String birthDate;

  /// male, female, non_binary ou other (escolhido ao criar a conta).
  final String gender;

  /// Já viu (ou saltou) o mini-guia de boas-vindas.
  final bool onboardingSeen;

  /// Interruptor geral de notificações push (Perfil).
  final bool pushEnabled;

  /// @username (único) e tag de 3 algarismos (fixa). Os outros convidam-te com "username#tag".
  final String username;
  final String usernameTag;

  /// Mudanças de username gratuitas que ainda tens (só 1 por conta; as seguintes serão pagas no futuro).
  final int usernameChangesLeft;

  /// "@hugo#482"
  String get handle => username.isEmpty ? '' : '@$username#$usernameTag';

  /// Pode mudar o username agora?
  bool get canChangeUsername => usernameChangesLeft > 0;

  AppUser copyWith({
    String? displayName,
    String? username,
    String? usernameTag,
    int? usernameChangesLeft,
    bool? onboardingSeen,
    bool? pushEnabled,
  }) =>
      AppUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        role: role,
        emailVerified: emailVerified,
        birthDate: birthDate,
        username: username ?? this.username,
        usernameTag: usernameTag ?? this.usernameTag,
        usernameChangesLeft: usernameChangesLeft ?? this.usernameChangesLeft,
        gender: gender,
        onboardingSeen: onboardingSeen ?? this.onboardingSeen,
        pushEnabled: pushEnabled ?? this.pushEnabled,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        role: (json['role'] ?? 'Player').toString(),
        emailVerified: json['emailVerified'] == true,
        birthDate: (json['birthDate'] ?? '').toString(),
        gender: (json['gender'] ?? 'other').toString(),
        onboardingSeen: json['onboardingSeen'] != false,
        pushEnabled: json['pushEnabled'] != false,
        username: (json['username'] ?? '').toString(),
        usernameTag: (json['usernameTag'] ?? '').toString(),
        usernameChangesLeft: (json['usernameChangesLeft'] as num?)?.toInt() ?? 1,
      );
}

class LegalInfo {
  const LegalInfo({
    required this.termsVersion,
    required this.privacyVersion,
    this.requiresAcceptance = false,
  });

  final String termsVersion;
  final String privacyVersion;
  final bool requiresAcceptance;

  /// Resposta de login/refresh: {termsVersion, privacyVersion, requiresAcceptance}
  factory LegalInfo.fromSession(Map<String, dynamic> json) => LegalInfo(
        termsVersion: (json['termsVersion'] ?? '').toString(),
        privacyVersion: (json['privacyVersion'] ?? '').toString(),
        requiresAcceptance: json['requiresAcceptance'] == true,
      );

  /// Resposta de GET /legal/current: {terms:{version}, privacy:{version}}
  factory LegalInfo.fromCurrent(Map<String, dynamic> json) {
    String version(String key) {
      final value = json[key];
      if (value is Map && value['version'] != null) {
        return value['version'].toString();
      }
      return '';
    }

    return LegalInfo(
      termsVersion: version('terms'),
      privacyVersion: version('privacy'),
    );
  }
}

class LegalText {
  const LegalText({required this.version, required this.text});

  final String version;
  final String text;
}
