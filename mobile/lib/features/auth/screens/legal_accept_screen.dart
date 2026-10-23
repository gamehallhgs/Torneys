import 'package:flutter/material.dart';

import '../../../core/auth_scope.dart';
import '../../../core/error_messages.dart';
import '../../../core/models.dart';
import '../../../widgets/gh_widgets.dart';
import 'legal_viewer_screen.dart';

/// Mostrado quando os Termos/Política mudam de versão: o utilizador tem de voltar a aceitar.
class LegalAcceptScreen extends StatefulWidget {
  const LegalAcceptScreen({super.key});

  @override
  State<LegalAcceptScreen> createState() => _LegalAcceptScreenState();
}

class _LegalAcceptScreenState extends State<LegalAcceptScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _busy = false;
  String? _error;

  void _open(String type) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalViewerScreen(type: type),
    ));
  }

  Future<void> _accept(LegalInfo legal) async {
    if (_busy) {
      return;
    }
    if (!_terms || !_privacy) {
      setState(() => _error = 'Tens de aceitar os dois documentos para continuar.');
      return;
    }
    final auth = AuthScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.acceptLegal(legal);
      // O ecrã raiz muda sozinho para a Home.
    } catch (e, st) {
      debugPrint('[GameHall] erro: $e\n$st');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final legal = auth.legal;
    return GhPage(
      showBack: false,
      title: 'Documentos atualizados',
      children: [
        const Text(
          'Atualizámos os Termos e Condições e/ou a Política de Privacidade. '
          'Para continuares a usar a app, lê e aceita as novas versões.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_error != null) GhBanner.error(_error!),
        GhCheckRow(
          value: _terms,
          onChanged: (v) => setState(() => _terms = v),
          label: 'Li e aceito os',
          linkLabel: 'Termos e Condições',
          onOpen: () => _open('terms'),
        ),
        GhCheckRow(
          value: _privacy,
          onChanged: (v) => setState(() => _privacy = v),
          label: 'Li e aceito a',
          linkLabel: 'Política de Privacidade',
          onOpen: () => _open('privacy'),
        ),
        const SizedBox(height: 20),
        GhButton(
          label: 'Aceitar e continuar',
          loading: _busy,
          onPressed: legal == null ? null : () => _accept(legal),
        ),
        const SizedBox(height: 8),
        GhLink(
          label: 'Terminar sessão',
          onPressed: _busy ? null : () => auth.logout(),
        ),
      ],
    );
  }
}
