import '../../core/api_client.dart';
import '../../core/validators.dart';
import 'tournament_models.dart';

/// Chamadas à API de torneios.
class TournamentsRepository {
  TournamentsRepository(this._api);

  final ApiClient _api;

  Future<TournamentPage> list({
    String? status,
    DateTime? from,
    DateTime? to,
    String? sport,
    String? district,
    String? municipality,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      if (status != null) 'status': status,
      if (from != null) 'from': Validators.formatDateApi(from),
      if (to != null) 'to': Validators.formatDateApi(to),
      if (sport != null) 'sport': sport,
      if (district != null) 'district': district,
      if (district != null && municipality != null) 'municipality': municipality,
      'page': '$page',
      'pageSize': '$pageSize',
    };
    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final res = (await _api.get('/api/v1/tournaments?$qs', auth: true)).ensureOk();
    return TournamentPage.fromJson(res.json);
  }

  Future<TournamentDetail> detail(String id) async {
    final res = (await _api.get('/api/v1/tournaments/$id', auth: true)).ensureOk();
    return TournamentDetail.fromJson(res.json);
  }
}
