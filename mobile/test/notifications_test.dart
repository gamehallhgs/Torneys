import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/notifications/notification_bell.dart';
import 'package:gamehall_torneios/features/notifications/notification_models.dart';
import 'package:gamehall_torneios/features/notifications/notifications_screen.dart';

Map<String, dynamic> inviteJson({String status = 'pending', bool read = false}) => {
      'id': 'n1',
      'type': 'team_invite',
      'createdAt': '2026-10-23T20:00:00Z',
      'read': read,
      'invite': {
        'inviteId': 'i1',
        'status': status,
        'teamId': 't1',
        'teamName': 'Dragões Urbanos',
        'colorHex': '#E53935',
        'tournamentId': 'a1',
        'tournamentName': 'Taça Outono',
        'invitedByName': 'Tomás Alves',
      },
    };

AppNotification notification({String status = 'pending', bool read = false}) =>
    AppNotification.fromJson(inviteJson(status: status, read: read));

Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('modelos', () {
    test('lê a lista com a contagem de novas', () {
      final list = NotificationList.fromJson({
        'unreadCount': 1,
        'items': [inviteJson()],
      });
      expect(list.unreadCount, 1);
      expect(list.items.single.invite!.teamName, 'Dragões Urbanos');
      expect(list.items.single.invite!.isPending, isTrue);
      expect(list.items.single.read, isFalse);
    });

    test('lista vazia', () {
      final list = NotificationList.fromJson({'unreadCount': 0, 'items': []});
      expect(list.items, isEmpty);
    });

    test('estados finais do convite', () {
      expect(NotificationLabels.inviteOutcome('pending'), isNull);
      expect(NotificationLabels.inviteOutcome('accepted'), contains('Aceitaste'));
      expect(NotificationLabels.inviteOutcome('declined'), contains('Recusaste'));
      expect(NotificationLabels.inviteOutcome('cancelled'), contains('cancelado'));
    });

    test('há quanto tempo', () {
      final now = DateTime(2026, 10, 23, 12);
      expect(NotificationLabels.ago(now.subtract(const Duration(seconds: 20)), now: now), 'agora');
      expect(NotificationLabels.ago(now.subtract(const Duration(minutes: 5)), now: now), 'há 5 min');
      expect(NotificationLabels.ago(now.subtract(const Duration(hours: 3)), now: now), 'há 3 h');
      expect(NotificationLabels.ago(now.subtract(const Duration(days: 1, hours: 2)), now: now), 'há 1 dia');
      expect(NotificationLabels.ago(now.subtract(const Duration(days: 3)), now: now), 'há 3 dias');
      expect(NotificationLabels.ago(DateTime(2026, 10, 1), now: now), '01/10/2026');
    });
  });

  group('sino', () {
    testWidgets('mostra o pontinho vermelho só quando há novas', (tester) async {
      await tester.pumpWidget(host(NotificationBellIcon(hasUnread: true, onPressed: () {})));
      expect(find.byKey(const ValueKey('notification-dot')), findsOneWidget);

      await tester.pumpWidget(host(NotificationBellIcon(hasUnread: false, onPressed: () {})));
      expect(find.byKey(const ValueKey('notification-dot')), findsNothing);
    });

    testWidgets('toque chama onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(NotificationBellIcon(hasUnread: false, onPressed: () => taps++)));
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });
  });

  group('cartão de convite', () {
    Widget card(AppNotification n, {VoidCallback? onAccept, VoidCallback? onDecline, bool busy = false}) =>
        host(InviteNotificationCard(
          notification: n,
          busy: busy,
          onOpenTeam: () {},
          onAccept: onAccept ?? () {},
          onDecline: onDecline ?? () {},
        ));

    testWidgets('pendente: texto, Novo e botões aceitar/recusar', (tester) async {
      var accepted = 0;
      var declined = 0;
      await tester.pumpWidget(card(notification(), onAccept: () => accepted++, onDecline: () => declined++));
      expect(find.text('Convite para a equipa Dragões Urbanos'), findsOneWidget);
      expect(find.textContaining('Tomás Alves convidou-te'), findsOneWidget);
      expect(find.textContaining('Taça Outono'), findsOneWidget);
      expect(find.text('Novo'), findsOneWidget);

      await tester.tap(find.text('Aceitar'));
      await tester.tap(find.text('Recusar'));
      expect(accepted, 1);
      expect(declined, 1);
    });

    testWidgets('já lida não tem a etiqueta Novo', (tester) async {
      await tester.pumpWidget(card(notification(read: true)));
      expect(find.text('Novo'), findsNothing);
    });

    testWidgets('aceite: sem botões, com estado e atalho para a equipa', (tester) async {
      await tester.pumpWidget(card(notification(status: 'accepted', read: true)));
      expect(find.text('Aceitar'), findsNothing);
      expect(find.text('Recusar'), findsNothing);
      expect(find.text('Aceitaste o convite'), findsOneWidget);
      expect(find.text('Ver equipa'), findsOneWidget);
    });

    testWidgets('recusado e cancelado: só o estado', (tester) async {
      await tester.pumpWidget(card(notification(status: 'declined', read: true)));
      expect(find.text('Recusaste o convite'), findsOneWidget);
      expect(find.text('Ver equipa'), findsNothing);

      await tester.pumpWidget(card(notification(status: 'cancelled', read: true)));
      expect(find.text('Convite cancelado ou expirado'), findsOneWidget);
      expect(find.text('Aceitar'), findsNothing);
    });

    testWidgets('ocupado desativa os botões', (tester) async {
      var accepted = 0;
      await tester.pumpWidget(card(notification(), busy: true, onAccept: () => accepted++));
      await tester.tap(find.text('Aceitar'), warnIfMissed: false);
      expect(accepted, 0);
    });
  });
}
