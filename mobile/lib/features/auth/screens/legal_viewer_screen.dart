import 'package:flutter/material.dart';

import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/models.dart';
import '../../../widgets/gh_widgets.dart';
import '../../../widgets/simple_markdown.dart';

/// Mostra os Termos e Condições ou a Política de Privacidade (texto vindo da API).
class LegalViewerScreen extends StatefulWidget {
  const LegalViewerScreen({super.key, required this.type});

  /// 'terms' ou 'privacy'
  final String type;

  @override
  State<LegalViewerScreen> createState() => _LegalViewerScreenState();
}

class _LegalViewerScreenState extends State<LegalViewerScreen> {
  LegalText? _text;
  String? _error;
  bool _started = false;

  String get _title =>
      widget.type == 'terms' ? 'Termos e Condições' : 'Política de Privacidade';

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
      _text = null;
    });
    try {
      final text = await AuthScope.of(context).fetchLegalText(widget.type);
      if (mounted) {
        setState(() => _text = text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    return GhPage(
      title: _title,
      children: [
        if (_error != null) ...[
          GhBanner.error(_error!),
          GhButton(label: 'Tentar novamente', onPressed: _load),
        ] else if (text == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          )
        else ...[
          Text(
            'Versão ${text.version}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SimpleMarkdown(text.text),
        ],
      ],
    );
  }
}
