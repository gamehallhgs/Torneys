import '../../core/api_client.dart';
import 'game_models.dart';

/// Chamadas à API de jogos, classificação e estatísticas (só leitura).
class GamesRepository {
  GamesRepository(this._api);

  final ApiClient _api;

  Future<List<Game>> games(String tournamentId) async {
    final res = (await _api.get('/api/v1/tournaments/$tournamentId/games', auth: true)).ensureOk();
    final data = res.data;
    if (data is! List) {
      return <Game>[];
    }
    return data.map((e) => Game.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<GameDetail> game(String gameId) async {
    final res = (await _api.get('/api/v1/games/$gameId', auth: true)).ensureOk();
    return GameDetail.fromJson(res.json);
  }

  Future<Standings> standings(String tournamentId) async {
    final res = (await _api.get('/api/v1/tournaments/$tournamentId/standings', auth: true)).ensureOk();
    return Standings.fromJson(res.json);
  }

  Future<TournamentStats> stats(String tournamentId) async {
    final res = (await _api.get('/api/v1/tournaments/$tournamentId/stats', auth: true)).ensureOk();
    return TournamentStats.fromJson(res.json);
  }
}
