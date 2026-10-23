import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/core/api_client.dart';
import 'package:gamehall_torneios/core/error_messages.dart';
import 'package:gamehall_torneios/features/teams/team_models.dart';

void main() {
  group('TeamLabels', () {
    test('todas as posições têm nome em português', () {
      expect(TeamLabels.positionCodes, hasLength(15));
      for (final code in TeamLabels.positionCodes) {
        expect(TeamLabels.position(code), isNot(code));
      }
    });

    test('a paleta tem cores #RRGGBB únicas', () {
      final re = RegExp(r'^#[0-9A-F]{6}$');
      expect(TeamLabels.palette.every(re.hasMatch), isTrue);
      expect(TeamLabels.palette.toSet(), hasLength(TeamLabels.palette.length));
    });

    test('joinBlocked devolve mensagem para cada motivo', () {
      for (final r in [
        'team_not_joinable', 'already_member', 'registration_closed', 'already_in_team',
        'age_too_young', 'age_too_old', 'team_full', 'team_confirmed', 'request_pending', 'lobby_closed',
      ]) {
        expect(TeamLabels.joinBlocked(r), isNot('Não podes entrar nesta equipa.'));
      }
      expect(TeamLabels.joinBlocked(null), 'Não podes entrar nesta equipa.');
    });
  });

  group('TeamLobby.fromJson', () {
    final host = {
      'team': {'id': 't1', 'name': 'Águias', 'colorHex': '#E53935', 'isDemo': false, 'confirmed': false},
      'tournament': {
        'id': 'x1', 'name': 'Taça', 'status': 'registration_open',
        'minPlayers': 7, 'maxPlayers': 12, 'teamsConfirmed': 3, 'maxTeams': 8,
      },
      'membersCount': 2,
      'members': [
        {'userId': 'u1', 'displayName': 'Ana', 'position': 'GK', 'isHost': true, 'isMe': true, 'paid': true},
        {'userId': 'u2', 'displayName': 'Rui', 'position': null, 'isHost': false, 'isMe': false, 'paid': false},
      ],
      'missingPositions': 1,
      'requests': [
        {'id': 'r1', 'userId': 'u3', 'displayName': 'Eva', 'createdAt': '2026-01-01T00:00:00Z'},
      ],
      'invites': [],
      'me': {
        'isMember': true, 'isHost': true, 'pendingRequestId': null, 'pendingInviteId': null,
        'myTeamIdInTournament': 't1', 'canRequestToJoin': false, 'joinBlockedReason': 'already_member',
      },
    };

    test('lê o lobby do líder', () {
      final l = TeamLobby.fromJson(host);
      expect(l.name, 'Águias');
      expect(l.isHost, isTrue);
      expect(l.members, hasLength(2));
      expect(l.me?.displayName, 'Ana');
      expect(l.requests.single.displayName, 'Eva');
      expect(l.belowMinimum, isTrue);
      expect(l.registrationOpen, isTrue);
      expect(l.missingPositions, 1);
      expect(l.confirmed, isFalse);
      expect(l.teamsConfirmed, 3);
      expect(l.maxTeams, 8);
      expect(l.unpaidCount, 1);
      expect(l.members.first.paid, isTrue);
    });

    test('equipa confirmada', () {
      final confirmed = Map<String, dynamic>.from(host)
        ..['team'] = {'id': 't1', 'name': 'Águias', 'colorHex': '#E53935', 'isDemo': false, 'confirmed': true};
      expect(TeamLobby.fromJson(confirmed).confirmed, isTrue);
    });

    test('lê o lobby de um visitante (sem membros)', () {
      final visitor = Map<String, dynamic>.from(host)
        ..['members'] = []
        ..['requests'] = []
        ..['me'] = {
          'isMember': false, 'isHost': false, 'canRequestToJoin': true,
          'pendingRequestId': null, 'pendingInviteId': null,
        };
      final l = TeamLobby.fromJson(visitor);
      expect(l.isMember, isFalse);
      expect(l.members, isEmpty);
      expect(l.me, isNull);
      expect(l.canRequestToJoin, isTrue);
    });
  });

  test('MyTeam e MyInvolvement lêem o JSON', () {
    final t = MyTeam.fromJson({
      'teamId': 't1', 'name': 'A', 'colorHex': '#1E88E5', 'tournamentName': 'T',
      'tournamentStatus': 'registration_open', 'isHost': true, 'membersCount': 3,
      'minPlayers': 7, 'maxPlayers': 12, 'pendingRequests': 2,
    });
    expect(t.isHost, isTrue);
    expect(t.pendingRequests, 2);

    final i = MyInvolvement.fromJson({
      'id': 'i1', 'teamId': 't1', 'teamName': 'A', 'colorHex': '#1E88E5',
      'tournamentName': 'T', 'invitedByName': 'Ana',
    });
    expect(i.invitedByName, 'Ana');
  });

  test('friendlyError traduz os códigos das equipas', () {
    String msg(String code) => friendlyError(ApiException(status: 409, code: code, message: 'x'));
    expect(msg('team_name_taken'), contains('nome'));
    expect(msg('team_color_taken'), contains('cor'));
    expect(msg('host_must_transfer'), contains('liderança'));
    expect(msg('team_full'), contains('completa'));
    expect(msg('team_confirmed'), contains('confirmada'));
    expect(msg('tournament_full'), contains('confirmadas'));
  });
}
