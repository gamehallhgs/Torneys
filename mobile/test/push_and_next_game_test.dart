import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/auth_controller.dart';
import 'package:gamehall_torneios/core/auth_scope.dart';
import 'package:gamehall_torneios/core/models.dart';
import 'package:gamehall_torneios/core/push_service.dart';
import 'package:gamehall_torneios/core/token_store.dart';
import 'package:gamehall_torneios/features/games/game_models.dart';
import 'package:gamehall_torneios/features/games/game_widgets.dart';
import 'package:gamehall_torneios/features/notifications/notification_models.dart';
import 'package:gamehall_torneios/features/notifications/notifications_screen.dart';
import 'package:gamehall_torneios/features/profile/profile_screen.dart';

import 'game_models_test.dart' show gameJson;

class _Store extends TokenStore {
  String? token = 'r1';

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<void> saveRefreshToken(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

class _Api extends ApiClient {
  bool pushEnabled = true;
  final List<String> calls = [];
  final List<Object?> bodies = [];

  Map<String, dynamic> _user() => {
        'id': 'u1',
        'email': 'a@b.pt',
        'displayName': 'Ana',
        'role': 'Player',
        'emailVerified': true,
        'birthDate': '2000-01-01',
        'pushEnabled': pushEnabled,
      };

  @override
  Future<ApiResponse> post(String path, {Object? body, bool auth = false}) async {
    calls.add('POST $path');
    bodies.add(body);
    if (path.endsWith('/auth/refresh')) {
      return ApiResponse(200, {
        'accessToken': 'a',
        'refreshToken': 'r2',
        'user': _user(),
        'legal': {'termsVersion': '1', 'privacyVersion': '1', 'requiresAcceptance': false},
      });
    }
    return ApiResponse(204, null);
  }

  @override
  Future<ApiResponse> put(String path, {Object? body, bool auth = false}) async {
    calls.add('PUT $path');
    pushEnabled = (body as Map)['enabled'] == true;
    return ApiResponse(200, _user());
  }
}

class _FakePush implements PushService {
  _FakePush(this._token);

  final String? _token;
  void Function(String)? refresh;

  @override
  String get platform => 'android';

  @override
  Future<String?> token() async => _token;

  @override
  void onTokenRefresh(void Function(String token) listener) => refresh = listener;
}

Map<String, dynamic> infoJson(String type, {bool exists = true}) => {
      'id': 'n9',
      'type': type,
      'createdAt': '2026-10-29T20:00:00Z',
      'read': false,
      'info': {
        'tournamentId': 't1',
        'tournamentName': 'Taça Outono',
        'gameId': type == 'game_starting' ? 'g1' : null,
        'title': 'Votação aberta',
        'message': 'Já podes votar.',
        'tournamentExists': exists,
      },
    };

void main() {
  group('notificações de torneio/jogo', () {
    test('lê o bloco info e reconhece os tipos', () {
      for (final t in [
        'voting_opened',
        'voting_second_round',
        'voting_results',
        'game_starting',
        'game_changed',
      ]) {
        final n = AppNotification.fromJson(infoJson(t));
        expect(AppNotification.infoTypes.contains(n.type), isTrue, reason: t);
        expect(n.info!.tournamentName, 'Taça Outono');
        expect(n.event, isNull);
      }
      expect(AppNotification.fromJson(infoJson('game_starting')).info!.gameId, 'g1');
    });

    testWidgets('cartão mostra título, texto e "Ver torneio"', (tester) async {
      var opened = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentEventNotificationCard(
            notification: AppNotification.fromJson(infoJson('voting_opened')),
            onOpenTournament: () => opened = true,
          ),
        ),
      ));
      expect(find.text('Votação aberta'), findsOneWidget);
      expect(find.text('Já podes votar.'), findsOneWidget);
      await tester.tap(find.text('Ver torneio'));
      expect(opened, isTrue);
    });

    testWidgets('torneio apagado: sem botão', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TournamentEventNotificationCard(
            notification: AppNotification.fromJson(infoJson('voting_results', exists: false)),
          ),
        ),
      ));
      expect(find.text('Ver torneio'), findsNothing);
      expect(find.text('O torneio já não existe.'), findsOneWidget);
    });
  });

  group('próximo jogo', () {
    test('lê next e mine; vazio quando não há nenhum', () {
      final both = NextGames.fromJson({
        'next': gameJson(id: 'a', status: 'scheduled', hg: null, ag: null),
        'mine': gameJson(id: 'b', status: 'scheduled', hg: null, ag: null),
      });
      expect(both.next!.id, 'a');
      expect(both.mine!.id, 'b');
      expect(both.sameGame, isFalse);
      expect(NextGames.fromJson({'next': null, 'mine': null}).isEmpty, isTrue);
    });

    test('se o meu jogo é o próximo do torneio, é o mesmo jogo', () {
      final g = gameJson(id: 'a', status: 'scheduled', hg: null, ag: null);
      expect(NextGames.fromJson({'next': g, 'mine': g}).sameGame, isTrue);
    });

    testWidgets('dois cartões quando são jogos diferentes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NextGamesSection(
              games: NextGames.fromJson({
                'next': gameJson(id: 'a', status: 'scheduled', hg: null, ag: null),
                'mine': gameJson(id: 'b', status: 'scheduled', hg: null, ag: null),
              }),
              onOpenGame: (_) {},
            ),
          ),
        ),
      ));
      expect(find.text('O meu próximo jogo'), findsOneWidget);
      expect(find.text('Próximo jogo do torneio'), findsOneWidget);
    });

    testWidgets('um só cartão quando é o mesmo jogo; nada quando não há jogos', (tester) async {
      final g = gameJson(id: 'a', status: 'scheduled', hg: null, ag: null);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NextGamesSection(games: NextGames.fromJson({'next': g, 'mine': g}), onOpenGame: (_) {}),
          ),
        ),
      ));
      expect(find.text('O meu próximo jogo'), findsOneWidget);
      expect(find.text('Próximo jogo do torneio'), findsNothing);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NextGamesSection(games: const NextGames(), onOpenGame: (_) {}),
        ),
      ));
      expect(find.text('O meu próximo jogo'), findsNothing);
    });

    testWidgets('só o próximo do torneio para quem não joga', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: NextGamesSection(
              games: NextGames.fromJson({
                'next': gameJson(id: 'a', status: 'scheduled', hg: null, ag: null),
                'mine': null,
              }),
              onOpenGame: (_) {},
            ),
          ),
        ),
      ));
      expect(find.text('O meu próximo jogo'), findsNothing);
      expect(find.text('Próximo jogo do torneio'), findsOneWidget);
    });
  });

  group('push', () {
    test('AppUser lê pushEnabled (por defeito ligado)', () {
      final base = {
        'id': '1',
        'email': 'a@b.pt',
        'displayName': 'Ana',
        'role': 'Player',
        'emailVerified': true,
        'birthDate': '2000-01-01',
      };
      expect(AppUser.fromJson(base).pushEnabled, isTrue);
      expect(AppUser.fromJson({...base, 'pushEnabled': false}).pushEnabled, isFalse);
      expect(AppUser.fromJson(base).copyWith(pushEnabled: false).pushEnabled, isFalse);
    });

    test('regista o telemóvel ao iniciar sessão e remove-o ao sair', () async {
      final api = _Api();
      final auth = AuthController(api: api, store: _Store(), push: _FakePush('token-do-telemovel-123456'));
      await auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, contains('POST /api/v1/me/devices'));
      expect(api.bodies[api.calls.indexOf('POST /api/v1/me/devices')], {
        'token': 'token-do-telemovel-123456',
        'platform': 'android',
      });

      // Outro refresh com o mesmo token não volta a registar.
      final before = api.calls.where((c) => c.endsWith('/me/devices')).length;
      await auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.where((c) => c.endsWith('/me/devices')).length, before);

      await auth.logout();
      expect(api.calls, contains('POST /api/v1/me/devices/remove'));
    });

    test('sem serviço de push não há chamadas de dispositivo', () async {
      final api = _Api();
      final auth = AuthController(api: api, store: _Store());
      await auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.where((c) => c.contains('/devices')), isEmpty);
    });

    test('token novo do Firebase é registado', () async {
      final api = _Api();
      final push = _FakePush('token-antigo-1234567890');
      final auth = AuthController(api: api, store: _Store(), push: push);
      await auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      push.refresh!('token-novo-0987654321');
      await Future<void>.delayed(Duration.zero);
      expect(api.bodies.whereType<Map>().where((b) => b['token'] == 'token-novo-0987654321'), hasLength(1));
    });

    testWidgets('o interruptor muda a definição na conta', (tester) async {
      final api = _Api();
      final auth = AuthController(api: api, store: _Store());
      await auth.refreshSession();
      expect(auth.user!.pushEnabled, isTrue);

      await tester.pumpWidget(AuthScope(
        controller: auth,
        child: const MaterialApp(home: Scaffold(body: PushSwitchTile())),
      ));
      expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('push-switch'))).value, isTrue);

      await tester.tap(find.byKey(const ValueKey('push-switch')));
      await tester.pumpAndSettle();

      expect(api.calls, contains('PUT /api/v1/me/push'));
      expect(auth.user!.pushEnabled, isFalse);
    });
  });
}
