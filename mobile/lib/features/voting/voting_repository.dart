import '../../core/api_client.dart';
import 'voting_models.dart';

/// Pódio, prémios e votação de um torneio terminado.
class VotingRepository {
  VotingRepository(this._api);

  final ApiClient _api;

  Future<TournamentResults> results(String tournamentId) async {
    final res = (await _api.get('/api/v1/tournaments/$tournamentId/results', auth: true)).ensureOk();
    return TournamentResults.fromJson(res.json);
  }

  /// Vota (ou muda o voto) numa categoria da votação aberta.
  Future<void> vote(String tournamentId, String category, String candidateUserId) async {
    (await _api.put(
      '/api/v1/tournaments/$tournamentId/voting/votes',
      body: {'category': category, 'candidateUserId': candidateUserId},
      auth: true,
    ))
        .ensureOk();
  }
}
