import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Endereço da API.
  ///
  /// - Emulador Android: http://10.0.2.2:8080 (o emulador vê o teu computador por este endereço)
  /// - Telemóvel real: usa o IP do computador na rede local:
  ///     flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }
}
