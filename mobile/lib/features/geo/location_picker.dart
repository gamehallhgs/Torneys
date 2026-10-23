import 'package:flutter/material.dart';

import '../../core/error_messages.dart';
import '../../core/theme.dart';
import 'geo_models.dart';

/// Tira acentos e maiúsculas para a pesquisa ("evora" encontra "Évora").
String foldText(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

/// Folha para escolher o distrito e, opcionalmente, o concelho. Devolve o filtro escolhido
/// (LocationFilter.none = todo o país) ou null se o utilizador fechar sem escolher.
Future<LocationFilter?> pickLocation(
  BuildContext context, {
  required GeoRepository geo,
  required LocationFilter current,
}) =>
    showModalBottomSheet<LocationFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GhColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: LocationPicker(geo: geo, current: current),
      ),
    );

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key, required this.geo, required this.current});

  final GeoRepository geo;
  final LocationFilter current;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  List<District> _districts = const [];
  bool _loading = true;
  String? _error;
  District? _district; // null = a escolher o distrito
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.geo.districts();
      if (!mounted) {
        return;
      }
      setState(() {
        _districts = list;
        _loading = false;
        for (final d in list) {
          if (d.name == widget.current.district) {
            _district = d;
          }
        }
      });
    } catch (e) {
      debugPrint('[GameHall] distritos falharam: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  void _done(LocationFilter f) => Navigator.of(context).pop(f);

  void _enter(District? d) => setState(() {
        _district = d;
        _query = '';
      });

  @override
  Widget build(BuildContext context) {
    final d = _district;
    final title = d == null ? 'Escolher distrito' : d.name;
    final q = foldText(_query.trim());
    final names = d == null ? _districts.map((x) => x.name).toList() : d.municipalities;
    final shown = q.isEmpty ? names : names.where((n) => foldText(n).contains(q)).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              children: [
                if (d != null)
                  IconButton(
                    tooltip: 'Voltar aos distritos',
                    onPressed: () => _enter(null),
                    icon: const Icon(Icons.arrow_back),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: d == null ? 'Pesquisar distrito' : 'Pesquisar concelho',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(onPressed: _load, child: const Text('Tentar novamente')),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          if (q.isEmpty)
                            ListTile(
                              leading: const Icon(Icons.public),
                              title: Text(d == null ? 'Todo o país' : 'Todos os concelhos de ${d.name}'),
                              selectedColor: GhColors.success,
                              selected: d == null
                                  ? !widget.current.isActive
                                  : widget.current.district == d.name && widget.current.municipality == null,
                              onTap: () => _done(
                                d == null ? LocationFilter.none : LocationFilter(district: d.name),
                              ),
                            ),
                          for (final n in shown)
                            ListTile(
                              title: Text(n),
                              trailing: d == null ? const Icon(Icons.chevron_right) : null,
                              selectedColor: GhColors.success,
                              selected: d == null
                                  ? widget.current.district == n
                                  : widget.current.district == d.name && widget.current.municipality == n,
                              onTap: () => d == null
                                  ? _enter(_districts.firstWhere((x) => x.name == n))
                                  : _done(LocationFilter(district: d.name, municipality: n)),
                            ),
                          if (shown.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Nada encontrado.', textAlign: TextAlign.center),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
