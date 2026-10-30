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
  Future<void> updateSettings(
    String teamId, {
    bool? isPrivate,
    bool? membersCanInvite,
    bool? inviteCodeEnabled,
    bool? codeDirectEntry,
    bool? membersSeeCode,
  }) async {
    (await _api.patch(
      '/api/v1/teams/$teamId/settings',
      body: {
        if (isPrivate != null) 'isPrivate': isPrivate,
        if (membersCanInvite != null) 'membersCanInvite': membersCanInvite,
        if (inviteCodeEnabled != null) 'inviteCodeEnabled': inviteCodeEnabled,
        if (codeDirectEntry != null) 'codeDirectEntry': codeDirectEntry,
        if (membersSeeCode != null) 'membersSeeCode': membersSeeCode,
      },
      auth: true,
    ))
        .ensureOk();
  }

  /// Só o líder: gera um código novo (o antigo deixa de funcionar). Máx. 3 por hora.
  Future<void> regenerateCode(String teamId) => _act('/api/v1/teams/$teamId/invite-code/regenerate');

  /// Mostra a equipa do código antes de entrar.
  Future<CodePreview> previewCode(String code) async {
    final res = (await _api.get('/api/v1/invite-codes/${Uri.encodeComponent(code)}', auth: true)).ensureOk();
    return CodePreview.fromJson(res.json);
  }

  /// Entra com o código. Devolve (teamId, entrouLogo); se não entrou logo, ficou um pedido pendente.
  Future<({String teamId, bool joined})> joinByCode(String code) async {
    final res = (await _api.post('/api/v1/invite-codes/${Uri.encodeComponent(code)}/join', auth: true)).ensureOk();
    final j = res.json;
    return (teamId: j['teamId'].toString(), joined: j['joined'] == true);
  }

  /// Só o líder: formação e lugares ([slots]: userId -> lugar; quem não vem fica suplente).
  Future<void> setLineup(String teamId, String formation, Map<String, int> slots) async {
    (await _api.put(
      '/api/v1/teams/$teamId/lineup',
      body: {
        'formation': formation,
        'slots': [for (final e in slots.entries) {'userId': e.key, 'slot': e.value}],
      },
      auth: true,
    ))
        .ensureOk();
  }

  /// Marca-me como preparado (ou não) para o pagamento.
  Future<void> setReady(String teamId, bool ready) => _act('/api/v1/teams/$teamId/ready', {'ready': ready});

  /// Só o líder. [paymentMode]: 'split' (cada um paga a sua parte) ou 'total' (o líder paga tudo).
  Future<void> close(String teamId, String paymentMode) =>
      _act('/api/v1/teams/$teamId/close', {'paymentMode': paymentMode});

  /// Só o líder, enquanto a vaga não está confirmada: volta à formação e liberta a vaga.
  Future<void> reopen(String teamId) => _act('/api/v1/teams/$teamId/reopen');

  /// Só o líder, enquanto a vaga não está confirmada: elimina a equipa.
  Future<void> disband(String teamId) => _act('/api/v1/teams/$teamId/disband');

  /// Pagamento SIMULADO (no futuro chama a API de pagamentos real).
  Future<void> pay(String teamId) => _act('/api/v1/teams/$teamId/pay');

  Future<void> requestJoin(String teamId) => _act('/api/v1/teams/$teamId/join-requests');
  /// Convida por email OU por username#tag (se vier [username], é esse que conta).
  Future<void> invite(String teamId, {String? email, String? username}) => _act(
        '/api/v1/teams/$teamId/invites',
        {if (username != null) 'username': username else 'email': email},
      );
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
