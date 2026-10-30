import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/error_messages.dart';
import 'package:gamehall_torneios/core/format.dart';
import 'package:gamehall_torneios/features/teams/team_models.dart';

Map<String, dynamic> lobbyJson({
  String state = 'forming',
  bool confirmed = false,
  DateTime? expiresAt,
  Map<String, dynamic>? payment,
  Map<String, dynamic>? me,
  bool isHost = true,
}) =>
    {
      'team': {
        'id': 't1', 'name': 'Águias', 'colorHex': '#E53935', 'isDemo': false,
        'confirmed': confirmed, 'isPrivate': false, 'membersCanInvite': false,
      },
      'tournament': {
        'id': 'a1', 'name': 'Taça', 'status': 'registration_open',
        'minPlayers': 7, 'maxPlayers': 12, 'teamsConfirmed': 1, 'maxTeams': 8,
      },
      'membersCount': 2,
      'members': [
        {'userId': 'u1', 'displayName': 'Ana', 'username': 'ana', 'position': 'GK', 'isHost': true,
         'isMe': isHost, 'paid': false, 'ready': true},
        {'userId': 'u2', 'displayName': 'Rui', 'username': 'rui', 'position': null, 'isHost': false,
         'isMe': !isHost, 'paid': false, 'ready': false},
      ],
      'missingPositions': 1,
      'requests': [],
      'invites': [],
      'me': {'isMember': true, 'isHost': isHost, 'canInvite': false, ...?me},
      'reservation': {
        'state': state,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'queuePosition': state == 'queued' ? 2 : null,
        'slotsTaken': 3,
        'maxTeams': 8,
        'reservationMinutes': 30,
        'penaltyMinutes': 15,
      },
      'payment': payment ??
          {
            'feeCents': 5000, 'mode': null, 'shareCents': 715, 'members': 7, 'collectedCents': 5005,
            'extraCents': 5, 'roundedUp': true, 'paidCount': 0, 'iPaid': false, 'canPay': false,
            'cannotPayReason': 'team_not_closed',
          },
    };

void main() {
  group('estado da equipa', () {
    test('em formação por defeito (e equipas antigas sem "reservation")', () {
      final json = lobbyJson()..remove('reservation')..remove('payment');
      final l = TeamLobby.fromJson(json);
      expect(l.state, TeamState.forming);
      expect(l.isForming, isTrue);
      expect(l.isClosed, isFalse);
      expect(l.payment.feeCents, 0);
    });

    test('sem "reservation" mas confirmada -> confirmed', () {
      final json = lobbyJson(confirmed: true)..remove('reservation');
      final l = TeamLobby.fromJson(json);
      expect(l.state, TeamState.confirmed);
      expect(l.isClosed, isTrue);
    });

    test('na fila: posição e fechada', () {
      final l = TeamLobby.fromJson(lobbyJson(state: 'queued'));
      expect(l.isQueued, isTrue);
      expect(l.isClosed, isTrue);
      expect(l.reservation.queuePosition, 2);
      expect(l.reservation.slotsTaken, 3);
    });

    test('vaga reservada: contador decrescente', () {
      final l = TeamLobby.fromJson(
          lobbyJson(state: 'reserved', expiresAt: DateTime.now().add(const Duration(minutes: 12, seconds: 30))));
      expect(l.isReserved, isTrue);
      expect(l.secondsLeft, inInclusiveRange(748, 751));
      final expired = TeamLobby.fromJson(
          lobbyJson(state: 'reserved', expiresAt: DateTime.now().subtract(const Duration(seconds: 5))));
      expect(expired.secondsLeft, lessThanOrEqualTo(0));
    });

    test('o que o líder pode fazer vem do servidor', () {
      final l = TeamLobby.fromJson(lobbyJson(me: {
        'ready': true, 'canClose': true, 'canReopen': false, 'canDisband': true,
        'closeBlockedReason': null,
      }));
      expect(l.canClose, isTrue);
      expect(l.canReopen, isFalse);
      expect(l.canDisband, isTrue);
      expect(l.iAmReady, isTrue);

      final blocked = TeamLobby.fromJson(lobbyJson(me: {
        'canClose': false,
        'closeBlockedReason': 'members_not_ready',
        'closeBlockedMessage': 'Falta 1 jogador marcar-se como preparado.',
      }));
      expect(blocked.canClose, isFalse);
      expect(blocked.closeBlockedMessage, contains('preparado'));
    });

    test('penalização só conta enquanto não passou', () {
      final active = TeamLobby.fromJson(lobbyJson(
          me: {'penaltyUntil': DateTime.now().add(const Duration(minutes: 9)).toUtc().toIso8601String()}));
      expect(active.isPenalized, isTrue);
      final over = TeamLobby.fromJson(lobbyJson(
          me: {'penaltyUntil': DateTime.now().subtract(const Duration(minutes: 1)).toUtc().toIso8601String()}));
      expect(over.isPenalized, isFalse);
      expect(TeamLobby.fromJson(lobbyJson()).isPenalized, isFalse);
    });

    test('membros: preparado e pago', () {
      final l = TeamLobby.fromJson(lobbyJson());
      expect(l.members[0].ready, isTrue);
      expect(l.members[1].ready, isFalse);
      final outsider = lobbyJson();
      for (final m in outsider['members'] as List) {
        (m as Map<String, dynamic>)
          ..remove('ready')
          ..remove('paid');
      }
      expect(TeamLobby.fromJson(outsider).members.every((m) => m.ready == null && m.paid == null), isTrue);
    });
  });

  group('pagamento', () {
    test('lê valores e o aviso de arredondamento', () {
      final p = TeamLobby.fromJson(lobbyJson()).payment;
      expect(p.feeCents, 5000);
      expect(p.shareCents, 715);
      expect(p.roundedUp, isTrue);
      expect(p.extraCents, 5);
      expect(p.collectedCents, 5005);
      expect(p.canPay, isFalse);
      expect(p.isTotal, isFalse);
    });

    test('modo total e já pagou', () {
      final p = TeamLobby.fromJson(lobbyJson(
        state: 'reserved',
        payment: {
          'feeCents': 5000, 'mode': 'total', 'shareCents': 5000, 'members': 7, 'collectedCents': 5000,
          'extraCents': 0, 'roundedUp': false, 'paidCount': 7, 'iPaid': true, 'canPay': false,
          'cannotPayReason': 'already_paid',
        },
      )).payment;
      expect(p.isTotal, isTrue);
      expect(p.roundedUp, isFalse);
      expect(p.iPaid, isTrue);
      expect(p.paidCount, 7);
    });

    test('valores formatados', () {
      expect(Fmt.money(715), '7,15 €');
      expect(Fmt.money(5000), '50 €');
    });
  });

  group('contador', () {
    test('formatCountdown', () {
      expect(formatCountdown(1800), '30:00');
      expect(formatCountdown(65), '1:05');
      expect(formatCountdown(9), '0:09');
      expect(formatCountdown(0), '0:00');
      expect(formatCountdown(-5), '0:00');
      expect(formatCountdown(3725), '1:02:05');
    });
  });

  group('Os meus torneios: estado', () {
    test('MyTeam lê o estado e o prazo da reserva', () {
      final t = MyTeam.fromJson({
        'teamId': 't1', 'name': 'Águias', 'colorHex': '#E53935', 'tournamentName': 'Taça',
        'tournamentStatus': 'registration_open', 'isHost': true, 'membersCount': 9, 'minPlayers': 9,
        'maxPlayers': 14, 'pendingRequests': 0, 'state': 'reserved',
        'reservationExpiresAt': '2026-10-26T10:30:00Z',
      });
      expect(t.state, TeamState.reserved);
      expect(t.reservationExpiresAt, DateTime.utc(2026, 10, 26, 10, 30));
    });

    test('rótulos dos estados', () {
      expect(TeamState.label('forming'), 'Em formação');
      expect(TeamState.label('queued'), 'Em fila');
      expect(TeamState.label('reserved'), 'Em pagamento');
      expect(TeamState.label('confirmed'), 'Confirmada');
    });

    test('sem estado -> em formação', () {
      final t = MyTeam.fromJson({'teamId': 't1', 'name': 'A', 'colorHex': '#000000'});
      expect(t.state, TeamState.forming);
      expect(t.reservationExpiresAt, isNull);
    });
  });

  group('mensagens de erro', () {
    String msg(String code, [String text = 'do servidor']) =>
        friendlyError(ApiException(status: 409, code: code, message: text));

    test('equipa fechada e vaga confirmada', () {
      expect(msg('team_closed'), contains('fechada'));
      expect(msg('team_confirmed_locked', 'A vaga já está confirmada.'), contains('confirmada'));
    });

    test('usa a mensagem do servidor nos erros com detalhes', () {
      for (final code in [
        'team_not_closed', 'team_in_queue', 'reservation_expired', 'only_host_pays', 'already_paid',
        'below_min_players', 'members_not_ready', 'members_penalized',
      ]) {
        expect(msg(code, 'Mensagem $code'), 'Mensagem $code');
      }
    });

    test('motivos para não entrar numa equipa fechada ou privada', () {
      expect(TeamLabels.joinBlocked('team_closed'), contains('fechada'));
      expect(TeamLabels.joinBlocked('lobby_private'), contains('privada'));
    });
  });
}
