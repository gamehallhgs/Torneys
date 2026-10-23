import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/teams/team_models.dart';

Map<String, dynamic> lobbyJson({
  bool isMember = true,
  bool isHost = true,
  bool closed = false,
  bool membersInvite = false,
  bool canInvite = true,
  bool? paid = true,
}) =>
    {
      'team': {
        'id': 't1',
        'name': 'Águias',
        'colorHex': '#E53935',
        'isDemo': false,
        'confirmed': false,
        'closedToRequests': closed,
        'membersCanInvite': membersInvite,
      },
      'tournament': {
        'id': 'a1',
        'name': 'Taça',
        'status': 'registration_open',
        'minPlayers': 7,
        'maxPlayers': 12,
        'teamsConfirmed': 1,
        'maxTeams': 8,
      },
      'membersCount': 2,
      'members': [
        {'userId': 'u1', 'displayName': 'Ana', 'position': 'GK', 'isHost': true, 'isMe': isMember, 'paid': paid},
        {'userId': 'u2', 'displayName': 'Rui', 'position': null, 'isHost': false, 'isMe': false, 'paid': paid},
      ],
      'missingPositions': 1,
      'requests': [],
      'invites': [],
      'me': {
        'isMember': isMember,
        'isHost': isHost,
        'canRequestToJoin': false,
        'joinBlockedReason': 'lobby_closed',
        'canInvite': canInvite,
      },
    };

void main() {
  test('lê as definições do lobby e a permissão de convidar', () {
    final l = TeamLobby.fromJson(lobbyJson(closed: true, membersInvite: true, canInvite: true));
    expect(l.closedToRequests, isTrue);
    expect(l.membersCanInvite, isTrue);
    expect(l.canInvite, isTrue);
    expect(l.joinBlockedReason, 'lobby_closed');
  });

  test('por defeito o lobby está aberto e só o líder convida', () {
    final l = TeamLobby.fromJson(lobbyJson(isHost: false, canInvite: false));
    expect(l.closedToRequests, isFalse);
    expect(l.membersCanInvite, isFalse);
    expect(l.canInvite, isFalse);
  });

  test('quem vê de fora conhece os membros mas não os pagamentos', () {
    final l = TeamLobby.fromJson(lobbyJson(isMember: false, isHost: false, canInvite: false, paid: null));
    expect(l.members, hasLength(2));
    expect(l.members.first.displayName, 'Ana');
    expect(l.members.every((m) => m.paid == null), isTrue);
    expect(l.unpaidCount, 0);
  });

  test('membros: conta só os que sabemos que não pagaram', () {
    final l = TeamLobby.fromJson(lobbyJson(paid: false));
    expect(l.unpaidCount, 2);
  });

  test('mensagem para lobby fechado', () {
    expect(TeamLabels.joinBlocked('lobby_closed'), contains('convite'));
  });
}
