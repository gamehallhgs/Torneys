import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/models.dart';
import 'package:gamehall_torneios/core/validators.dart';
import 'package:gamehall_torneios/features/notifications/notification_models.dart';
import 'package:gamehall_torneios/features/profile/username_check.dart';
import 'package:gamehall_torneios/features/teams/team_models.dart';

void main() {
  group('Validators.username', () {
    test('aceita usernames válidos (com @ e maiúsculas normaliza)', () {
      for (final v in ['hugo', '@Hugo', 'hugo.dias', 'hugo_dias', 'a.b', 'abc', 'x1.y2_z3', 'a' * 20]) {
        expect(Validators.username(v), isNull, reason: v);
      }
    });

    test('recusa os inválidos', () {
      for (final v in ['', 'ab', 'a' * 21, '.hugo', 'hugo.', '_hugo', 'hugo_', 'hu..go', 'hu go', 'joão', 'hugo-dias', 'hugo#482']) {
        expect(Validators.username(v), isNotNull, reason: v);
      }
      expect(Validators.username('hu..go'), contains('pontos seguidos'));
    });

    test('normalizeUsername', () {
      expect(Validators.normalizeUsername('  @Hugo.Dias '), 'hugo.dias');
      expect(Validators.normalizeUsername(null), '');
    });
  });

  group('Validators.parseHandle', () {
    test('username#tag', () {
      expect(Validators.parseHandle('hugo#482'), (username: 'hugo', tag: '482'));
      expect(Validators.parseHandle('@Hugo.Dias#007'), (username: 'hugo.dias', tag: '007'));
      expect(Validators.parseHandle('  hugo # 482 '), (username: 'hugo', tag: '482'));
    });

    test('sem tag ou com tag errada é inválido', () {
      for (final v in ['hugo', 'hugo#', 'hugo#48', 'hugo#4821', 'hugo#abc', '#482', 'hu#482', 'hu..go#482', null]) {
        expect(Validators.parseHandle(v), isNull, reason: '$v');
      }
    });
  });

  group('AppUser', () {
    AppUser user({DateTime? next}) => AppUser(
          id: '1',
          email: 'a@b.pt',
          displayName: 'Hugo Dias',
          role: 'Player',
          emailVerified: true,
          birthDate: '2000-01-01',
          username: 'hugo',
          usernameTag: '482',
          usernameNextChangeAt: next,
        );

    test('handle', () => expect(user().handle, '@hugo#482'));

    test('lê username, tag e quando pode mudar', () {
      final u = AppUser.fromJson({
        'id': '1',
        'email': 'a@b.pt',
        'displayName': 'Hugo',
        'role': 'Player',
        'emailVerified': true,
        'birthDate': '2000-01-01',
        'username': 'hugo',
        'usernameTag': '482',
        'usernameNextChangeAt': '2026-11-20T10:00:00Z',
      });
      expect(u.username, 'hugo');
      expect(u.usernameTag, '482');
      expect(u.usernameNextChangeAt, isNotNull);
    });

    test('só pode mudar quando passa a data', () {
      final now = DateTime(2026, 10, 24);
      expect(user().canChangeUsername(now: now), isTrue);
      expect(user(next: DateTime(2026, 11, 20)).canChangeUsername(now: now), isFalse);
      expect(user(next: DateTime(2026, 10, 1)).canChangeUsername(now: now), isTrue);
    });

    test('mudar o username mantém a tag', () {
      final u = user().copyWith(username: 'hugo.novo', usernameNextChangeAt: DateTime(2026, 11, 23));
      expect(u.handle, '@hugo.novo#482');
    });

    test('sem username não há handle', () {
      expect(const AppUser(
        id: '1', email: '', displayName: '', role: 'Player', emailVerified: true, birthDate: '',
      ).handle, '');
    });
  });

  group('nomes com @username', () {
    test('membro e pedido', () {
      final m = TeamMember.fromJson({
        'userId': 'u1', 'displayName': 'Ana', 'username': 'ana.s', 'position': 'GK', 'isHost': true, 'isMe': false,
      });
      expect(m.label, 'Ana (@ana.s)');
      final p = PendingItem.fromJson({'id': 'p1', 'userId': 'u2', 'displayName': 'Rui', 'username': 'rui'});
      expect(p.label, 'Rui (@rui)');
    });

    test('sem username mostra só o nome', () {
      final p = PendingItem.fromJson({'id': 'p1', 'userId': 'u2', 'displayName': 'Rui'});
      expect(p.label, 'Rui');
    });

    test('convite: quem convidou', () {
      final i = TeamInviteInfo.fromJson({
        'inviteId': 'i', 'status': 'pending', 'teamId': 't', 'teamName': 'X', 'colorHex': '#E53935',
        'tournamentId': 'a', 'tournamentName': 'T', 'invitedByName': 'Tomás Alves', 'invitedByUsername': 'tomas',
      });
      expect(i.invitedByLabel, 'Tomás Alves (@tomas)');
    });
  });

  group('UsernameField', () {
    Widget host(TextEditingController c, UsernameChecker check, {List<bool?>? log, String? current}) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: UsernameField(
                controller: c,
                check: check,
                currentUsername: current,
                onAvailabilityChanged: log?.add,
                debounce: const Duration(milliseconds: 100),
              ),
            ),
          ),
        );

    testWidgets('livre: mostra Disponível depois de esperar', (tester) async {
      final c = TextEditingController();
      final calls = <String>[];
      await tester.pumpWidget(host(c, (u) async {
        calls.add(u);
        return const UsernameCheck(available: true);
      }));
      await tester.enterText(find.byType(TextFormField), 'Hugo.Dias');
      await tester.pump();
      expect(find.text('A verificar...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Disponível'), findsOneWidget);
      expect(calls, ['hugo.dias']);
    });

    testWidgets('em uso: mostra a mensagem do servidor', (tester) async {
      final c = TextEditingController();
      final log = <bool?>[];
      await tester.pumpWidget(host(c, (u) async => const UsernameCheck(
            available: false,
            reason: 'taken',
            message: 'Este username já está em uso.',
          ), log: log));
      await tester.enterText(find.byType(TextFormField), 'hugo');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Este username já está em uso.'), findsOneWidget);
      expect(log.last, isFalse);
    });

    testWidgets('inválido localmente não chama o servidor', (tester) async {
      final c = TextEditingController();
      var calls = 0;
      await tester.pumpWidget(host(c, (u) async {
        calls++;
        return const UsernameCheck(available: true);
      }));
      await tester.enterText(find.byType(TextFormField), 'ab');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('entre 3 e 20'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('várias teclas seguidas fazem um só pedido', (tester) async {
      final c = TextEditingController();
      final calls = <String>[];
      await tester.pumpWidget(host(c, (u) async {
        calls.add(u);
        return const UsernameCheck(available: true);
      }));
      for (final t in ['hug', 'hugo', 'hugo.d', 'hugo.di']) {
        await tester.enterText(find.byType(TextFormField), t);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(calls, ['hugo.di']);
    });

    testWidgets('o username que já é teu não conta como livre', (tester) async {
      final c = TextEditingController();
      var calls = 0;
      await tester.pumpWidget(host(c, (u) async {
        calls++;
        return const UsernameCheck(available: true);
      }, current: 'hugo'));
      await tester.enterText(find.byType(TextFormField), '@Hugo');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Este já é o teu username.'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('sem rede não bloqueia', (tester) async {
      final c = TextEditingController();
      final log = <bool?>[];
      await tester.pumpWidget(host(c, (u) async => throw Exception('offline'), log: log));
      await tester.enterText(find.byType(TextFormField), 'hugo.dias');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(find.byKey(const ValueKey('username-status')), findsNothing);
      expect(log.last, isNull);
    });
  });
}
