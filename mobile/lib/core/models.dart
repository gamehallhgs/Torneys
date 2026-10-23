class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.emailVerified,
    required this.birthDate,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final bool emailVerified;
  final String birthDate;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        role: (json['role'] ?? 'Player').toString(),
        emailVerified: json['emailVerified'] == true,
        birthDate: (json['birthDate'] ?? '').toString(),
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
