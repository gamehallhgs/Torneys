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
    this.usernameNextChangeAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool emailVerified;
  final String birthDate;

  /// @username (único) e tag de 3 algarismos (fixa). Os outros convidam-te com "username#tag".
  final String username;
  final String usernameTag;

  /// Quando voltas a poder mudar o username (null = já podes).
  final DateTime? usernameNextChangeAt;

  /// "@hugo#482"
  String get handle => username.isEmpty ? '' : '@$username#$usernameTag';

  /// Pode mudar o username agora?
  bool canChangeUsername({DateTime? now}) =>
      usernameNextChangeAt == null || !usernameNextChangeAt!.isAfter(now ?? DateTime.now());

  AppUser copyWith({String? username, String? usernameTag, DateTime? usernameNextChangeAt}) => AppUser(
        id: id,
        email: email,
        displayName: displayName,
        role: role,
        emailVerified: emailVerified,
        birthDate: birthDate,
        username: username ?? this.username,
        usernameTag: usernameTag ?? this.usernameTag,
        usernameNextChangeAt: usernameNextChangeAt,
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        role: (json['role'] ?? 'Player').toString(),
        emailVerified: json['emailVerified'] == true,
        birthDate: (json['birthDate'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        usernameTag: (json['usernameTag'] ?? '').toString(),
        usernameNextChangeAt: json['usernameNextChangeAt'] == null
            ? null
            : DateTime.tryParse(json['usernameNextChangeAt'].toString())?.toLocal(),
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
