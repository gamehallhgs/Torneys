import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../widgets/gh_widgets.dart';

/// Direito de acesso/portabilidade (RGPD): mostra os dados da conta e permite copiá-los.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  String? _json;
  String? _error;
  String? _info;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _json = null;
    });
    try {
      final data = await AuthScope.of(context).exportData();
      if (mounted) {
        setState(() => _json = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _json ?? ''));
    if (mounted) {
      setState(() => _info = 'Copiado para a área de transferência.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final json = _json;
    return GhPage(
      title: 'Os meus dados',
      children: [
        const Text(
          'Estes são os dados pessoais que guardamos sobre ti.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          GhBanner.error(_error!),
          GhButton(label: 'Tentar novamente', onPressed: _load),
        ] else if (json == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        else ...[
          if (_info != null) GhBanner.success(_info!),
          GhButton(label: 'Copiar', onPressed: _copy),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}
