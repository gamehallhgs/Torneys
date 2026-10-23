import '../../core/api_client.dart';

/// Distrito de Portugal continental e respetivos concelhos (vem da API, GET /api/v1/geo/districts).
class District {
  const District({required this.name, required this.municipalities});

  final String name;
  final List<String> municipalities;

  factory District.fromJson(Map<String, dynamic> j) => District(
        name: (j['name'] ?? '').toString(),
        municipalities: ((j['municipalities'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// Filtro de localidade escolhido pelo utilizador. Sem distrito = todo o país.
class LocationFilter {
  const LocationFilter({this.district, this.municipality});

  static const none = LocationFilter();

  final String? district;
  final String? municipality;

  bool get isActive => district != null;

  /// Texto curto para o botão: "Lisboa", "Lisboa · Cascais" ou "Localidade".
  String get label => district == null
      ? 'Localidade'
      : municipality == null
          ? district!
          : '$district · $municipality';

  @override
  bool operator ==(Object other) =>
      other is LocationFilter && other.district == district && other.municipality == municipality;

  @override
  int get hashCode => Object.hash(district, municipality);
}

class GeoRepository {
  GeoRepository(this._api);

  final ApiClient _api;
  static List<District>? _cache;

  /// Os distritos não mudam: ficam em memória depois do primeiro pedido.
  Future<List<District>> districts() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    final res = (await _api.get('/api/v1/geo/districts', auth: true)).ensureOk();
    final data = res.data;
    final list = data is List
        ? data.map((e) => District.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <District>[];
    if (list.isNotEmpty) {
      _cache = list;
    }
    return list;
  }
}
