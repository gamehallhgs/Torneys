import '../../core/api_client.dart';
import 'team_models.dart';

/// Chamadas à API de equipas, pedidos e convites.
class TeamsRepository {
  TeamsRepository(this._api);

  final ApiClient _api;

  Future<TeamLobby> createTeam(String tournamentId, String name, String colorHex) async {
    final res = (await _api.post(
      '/api/v1/tournaments/$tournamentId/teams',
      body: {'name': name, 'colorHex': colorHex},
      auth: true,
    ))
        .ensureOk();
    return TeamLobby.fromJson(res.json);
  }

  Future<TeamLobby> lobby(String teamId) async {
    final res = (await _api.get('/api/v1/teams/$teamId', auth: true)).ensureOk();
    return TeamLobby.fromJson(res.json);
  }

  Future<void> _act(String path, [Object? body]) async {
    (await _api.post(path, body: body, auth: true)).ensureOk();
  }

  /// Só o líder. Só muda o que for enviado (null = não mexer).
  Future<void> updateSettings(String teamId, {bool? closedToRequests, bool? membersCanInvite}) async {
    (await _api.patch(
      '/api/v1/teams/$teamId/settings',
      body: {
        if (closedToRequests != null) 'closedToRequests': closedToRequests,
        if (membersCanInvite != null) 'membersCanInvite': membersCanInvite,
      },
      auth: true,
    ))
        .ensureOk();
  }

  Future<void> requestJoin(String teamId) => _act('/api/v1/teams/$teamId/join-requests');
  Future<void> invite(String teamId, String email) =>
      _act('/api/v1/teams/$teamId/invites', {'email': email});
  Future<void> setPosition(String teamId, String position) =>
      _act('/api/v1/teams/$teamId/position', {'position': position});
  Future<void> transferHost(String teamId, String userId) =>
      _act('/api/v1/teams/$teamId/transfer-host', {'userId': userId});
  Future<void> leave(String teamId) => _act('/api/v1/teams/$teamId/leave');
  Future<void> removeMember(String teamId, String userId) =>
      _act('/api/v1/teams/$teamId/members/$userId/remove');

  Future<void> acceptRequest(String id) => _act('/api/v1/join-requests/$id/accept');
  Future<void> rejectRequest(String id) => _act('/api/v1/join-requests/$id/reject');
  Future<void> cancelRequest(String id) => _act('/api/v1/join-requests/$id/cancel');

  Future<void> acceptInvite(String id) => _act('/api/v1/invites/$id/accept');
  Future<void> declineInvite(String id) => _act('/api/v1/invites/$id/decline');
  Future<void> cancelInvite(String id) => _act('/api/v1/invites/$id/cancel');

  Future<List<T>> _list<T>(String path, T Function(Map<String, dynamic>) parse) async {
    final res = (await _api.get(path, auth: true)).ensureOk();
    final data = res.data;
    if (data is! List) {
      return <T>[];
    }
    return data.map((e) => parse(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<MyTeam>> myTeams() => _list('/api/v1/my/teams', MyTeam.fromJson);
  Future<List<MyInvolvement>> myInvites() => _list('/api/v1/my/invites', MyInvolvement.fromJson);
  Future<List<MyInvolvement>> myRequests() =>
      _list('/api/v1/my/join-requests', MyInvolvement.fromJson);
}
