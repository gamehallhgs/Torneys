import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'models.dart';
import 'token_store.dart';

enum AuthStatus { loading, signedOut, legalRequired, signedIn }

/// Estado da sessão. Regra de ouro: só existe UM pedido de renovação (refresh) de cada vez,
/// porque a API trata dois refresh iguais em simultâneo como roubo de token e fecha a sessão.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.store}) {
    api.onRefresh = refreshSession;
  }

  final ApiClient api;
  final TokenStore store;

  AuthStatus _status = AuthStatus.loading;
  AppUser? _user;
  LegalInfo? _legal;
  Future<bool>? _refreshing;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  LegalInfo? get legal => _legal;

  // ---------- Arranque ----------

  Future<void> bootstrap() async {
    final token = await store.readRefreshToken();
    if (token == null) {
      _setStatus(AuthStatus.signedOut);
      return;
    }
    final ok = await refreshSession();
    if (!ok && _status == AuthStatus.loading) {
      _setStatus(AuthStatus.signedOut);
    }
  }

  // ---------- Legal (público) ----------

  Future<LegalInfo> fetchLegalCurrent() async {
    final res = (await api.get('/api/v1/legal/current')).ensureOk();
    return LegalInfo.fromCurrent(res.json);
  }

  Future<LegalText> fetchLegalText(String type) async {
    final res = (await api.get('/api/v1/legal/$type')).ensureOk();
    return LegalText(
      version: (res.json['version'] ?? '').toString(),
      text: (res.json['text'] ?? '').toString(),
    );
  }

  // ---------- Registo e verificação ----------

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String username,
    required String birthDateApi,
    required LegalInfo legal,
  }) async {
    (await api.post('/api/v1/auth/register', body: <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
      'username': username.trim(),
      'birthDate': birthDateApi,
      'acceptTerms': true,
      'acceptPrivacy': true,
      'termsVersion': legal.termsVersion,
      'privacyVersion': legal.privacyVersion,
    }))
        .ensureOk();
  }

  Future<void> verifyEmail(String email, String code) async {
    (await api.post('/api/v1/auth/verify-email', body: <String, dynamic>{
      'email': email.trim(),
      'code': code.trim(),
    }))
        .ensureOk();
  }

  Future<void> resendVerification(String email) async {
    (await api.post('/api/v1/auth/resend-verification',
            body: <String, dynamic>{'email': email.trim()}))
        .ensureOk();
  }

  // ---------- Login / logout ----------

  Future<void> login(String email, String password) async {
    final res = (await api.post('/api/v1/auth/login', body: <String, dynamic>{
      'email': email.trim(),
      'password': password,
      'deviceName': 'GameHall Torneios (app)',
    }))
        .ensureOk();
    await _applySession(res.json);
  }

  Future<void> logout() async {
    final token = await store.readRefreshToken();
    if (token != null) {
      try {
        await api.post('/api/v1/auth/logout',
            body: <String, dynamic>{'refreshToken': token});
      } on ApiException {
        // Mesmo sem rede, terminamos a sessão localmente.
      }
    }
    await _clearSession();
  }

  Future<void> logoutAll() async {
    (await api.post('/api/v1/me/logout-all', auth: true)).ensureOk();
    await _clearSession();
  }

  // ---------- Recuperação de palavra-passe ----------

  Future<void> forgotPassword(String email) async {
    (await api.post('/api/v1/auth/forgot-password',
            body: <String, dynamic>{'email': email.trim()}))
        .ensureOk();
  }

  Future<void> resetPassword(String email, String code, String newPassword) async {
    (await api.post('/api/v1/auth/reset-password', body: <String, dynamic>{
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    }))
        .ensureOk();
  }

  // ---------- Termos (reaceitação quando mudam de versão) ----------

  Future<void> acceptLegal(LegalInfo legal) async {
    (await api.post('/api/v1/me/consents',
            auth: true,
            body: <String, dynamic>{
              'termsVersion': legal.termsVersion,
              'privacyVersion': legal.privacyVersion,
            }))
        .ensureOk();
    // O token antigo ainda diz legal_ok=false: pedimos um novo.
    final ok = await refreshSession();
    if (!ok) {
      throw ApiException.network();
    }
  }

  // ---------- Conta ----------

  Future<void> changePassword(String current, String next) async {
    (await api.post('/api/v1/me/change-password',
            auth: true,
            body: <String, dynamic>{
              'currentPassword': current,
              'newPassword': next,
            }))
        .ensureOk();
    // A API revoga as outras sessões; esta continua válida.
  }

  /// Muda o username (1 vez por mês). A tag mantém-se.
  Future<void> changeUsername(String username) async {
    final res = (await api.patch('/api/v1/me/username',
            auth: true, body: <String, dynamic>{'username': username.trim()}))
        .ensureOk();
    final current = _user;
    if (current != null) {
      _user = current.copyWith(
        username: (res.json['username'] ?? current.username).toString(),
        usernameTag: (res.json['usernameTag'] ?? current.usernameTag).toString(),
        usernameNextChangeAt: res.json['nextChangeAt'] == null
            ? null
            : DateTime.tryParse(res.json['nextChangeAt'].toString())?.toLocal(),
      );
      notifyListeners();
    }
  }

  Future<String> exportData() async {
    final res = (await api.get('/api/v1/me/export', auth: true)).ensureOk();
    return const JsonEncoder.withIndent('  ').convert(res.data);
  }

  Future<void> deleteAccount(String password) async {
    (await api.post('/api/v1/me/delete',
            auth: true, body: <String, dynamic>{'password': password}))
        .ensureOk();
    await _clearSession();
  }

  // ---------- Renovação de sessão (uma de cada vez) ----------

  Future<bool> refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final token = await store.readRefreshToken();
    if (token == null) {
      await _clearSession();
      return false;
    }
    try {
      final res = await api.post('/api/v1/auth/refresh',
          body: <String, dynamic>{'refreshToken': token});
      if (res.ok) {
        await _applySession(res.json);
        return true;
      }
      if (res.status == 401) {
        // Refresh token inválido/expirado/revogado: a sessão acabou.
        await _clearSession();
      }
      return false;
    } catch (_) {
      // Sem rede (ou erro inesperado): mantemos o token guardado para tentar mais tarde.
      return false;
    }
  }

  // ---------- Interno ----------

  Future<void> _applySession(Map<String, dynamic> json) async {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final userJson = json['user'];
    final legalJson = json['legal'];
    if (access is! String || refresh is! String || userJson is! Map) {
      throw ApiException(
        status: 500,
        code: 'invalid_response',
        message: 'Resposta inesperada do servidor.',
      );
    }
    api.accessToken = access;
    await store.saveRefreshToken(refresh);
    _user = AppUser.fromJson(Map<String, dynamic>.from(userJson));
    _legal = legalJson is Map
        ? LegalInfo.fromSession(Map<String, dynamic>.from(legalJson))
        : null;
    _setStatus(_legal?.requiresAcceptance == true
        ? AuthStatus.legalRequired
        : AuthStatus.signedIn);
  }

  Future<void> _clearSession() async {
    api.accessToken = null;
    _user = null;
    _legal = null;
    await store.clear();
    _setStatus(AuthStatus.signedOut);
  }

  void _setStatus(AuthStatus value) {
    _status = value;
    notifyListeners();
  }
}
