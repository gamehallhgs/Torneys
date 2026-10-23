import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/auth_controller.dart';
import 'package:gamehall_torneios/core/token_store.dart';

class FakeStore extends TokenStore {
  String? token;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> saveRefreshToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class FakeApi extends ApiClient {
  FakeApi(this.handler);

  final Future<ApiResponse> Function(String path, Object? body) handler;
  final List<String> calls = [];

  @override
  Future<ApiResponse> post(String path, {Object? body, bool auth = false}) {
    calls.add(path);
    return handler(path, body);
  }

  @override
  Future<ApiResponse> get(String path, {bool auth = false}) {
    calls.add(path);
    return handler(path, null);
  }
}

Map<String, dynamic> session({bool requiresAcceptance = false, String refresh = 'r2'}) => {
      'tokenType': 'Bearer',
      'accessToken': 'access-1',
      'expiresIn': 900,
      'refreshToken': refresh,
      'user': {
        'id': 'u1',
        'email': 'a@b.pt',
        'displayName': 'Ana',
        'role': 'Player',
        'emailVerified': true,
        'birthDate': '2000-01-01',
      },
      'legal': {
        'termsVersion': '1.0.0',
        'privacyVersion': '1.0.0',
        'requiresAcceptance': requiresAcceptance,
      },
    };

void main() {
  test('dois refresh em simultâneo fazem apenas UM pedido à API', () async {
    final store = FakeStore()..token = 'r1';
    final api = FakeApi((path, body) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return ApiResponse(200, session());
    });
    final auth = AuthController(api: api, store: store);

    final results = await Future.wait([auth.refreshSession(), auth.refreshSession()]);

    expect(results, [true, true]);
    expect(api.calls.where((c) => c.endsWith('/auth/refresh')).length, 1);
    expect(store.token, 'r2');
    expect(auth.status, AuthStatus.signedIn);
    expect(api.accessToken, 'access-1');
  });

  test('refresh rejeitado (401) termina a sessão e apaga o token', () async {
    final store = FakeStore()..token = 'r1';
    final api = FakeApi((path, body) async =>
        ApiResponse(401, {'code': 'invalid_refresh_token', 'title': 'x'}));
    final auth = AuthController(api: api, store: store);

    await auth.bootstrap();

    expect(auth.status, AuthStatus.signedOut);
    expect(store.token, isNull);
  });

  test('sem token guardado, o arranque vai para signedOut sem chamar a API', () async {
    final store = FakeStore();
    final api = FakeApi((path, body) async => ApiResponse(500, null));
    final auth = AuthController(api: api, store: store);

    await auth.bootstrap();

    expect(auth.status, AuthStatus.signedOut);
    expect(api.calls, isEmpty);
  });

  test('login com requiresAcceptance leva ao ecrã de termos', () async {
    final store = FakeStore();
    final api = FakeApi((path, body) async =>
        ApiResponse(200, session(requiresAcceptance: true)));
    final auth = AuthController(api: api, store: store);

    await auth.login('a@b.pt', 'palavra-passe-longa');

    expect(auth.status, AuthStatus.legalRequired);
    expect(store.token, 'r2');
  });

  test('login com credenciais erradas lança ApiException com o código da API', () async {
    final store = FakeStore();
    final api = FakeApi((path, body) async =>
        ApiResponse(401, {'code': 'invalid_credentials', 'title': 'Credenciais inválidas'}));
    final auth = AuthController(api: api, store: store);

    expect(
      () => auth.login('a@b.pt', 'errada'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
  });

  test('ApiException agrega erros por campo', () {
    final e = ApiException.fromResponse(400, {
      'code': 'validation_error',
      'title': 'Dados inválidos',
      'errors': {
        'password': ['Muito curta']
      },
    });
    expect(e.code, 'validation_error');
    expect(e.fullMessage, 'Muito curta');
  });
}
