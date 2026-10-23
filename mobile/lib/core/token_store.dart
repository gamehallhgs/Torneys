import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o refresh token no Keychain (iOS) / Keystore (Android).
/// O access token (curto, 15 min) fica só em memória e é pedido de novo ao arrancar.
///
/// Se o armazenamento seguro falhar (acontece em alguns emuladores), a app continua a
/// funcionar com o token só em memória: a sessão perde-se ao fechar a app, mas nada rebenta.
class TokenStore {
  TokenStore() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _refreshKey = 'refresh_token';
  String? _memory;

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey) ?? _memory;
    } catch (e) {
      debugPrint('[GameHall] armazenamento seguro (leitura) falhou: $e');
      return _memory;
    }
  }

  Future<void> saveRefreshToken(String token) async {
    _memory = token;
    try {
      await _storage.write(key: _refreshKey, value: token);
    } catch (e) {
      debugPrint('[GameHall] armazenamento seguro (escrita) falhou: $e');
    }
  }

  Future<void> clear() async {
    _memory = null;
    try {
      await _storage.delete(key: _refreshKey);
    } catch (e) {
      debugPrint('[GameHall] armazenamento seguro (limpeza) falhou: $e');
    }
  }
}
