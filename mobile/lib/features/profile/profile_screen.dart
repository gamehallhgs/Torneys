import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../widgets/gh_widgets.dart';
import '../auth/screens/legal_viewer_screen.dart';
import 'change_password_screen.dart';
import 'delete_account_screen.dart';
import 'export_data_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  String? _error;

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _logout({required bool everywhere}) async {
    if (_busy) {
      return;
    }
    final auth = AuthScope.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (everywhere) {
        await auth.logoutAll();
      } else {
        await auth.logout();
      }
      navigator.popUntil((route) => route.isFirst);
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
    final user = AuthScope.of(context).user;
    return GhPage(
      title: 'Perfil',
      children: [
        if (_error != null) GhBanner.error(_error!),
        _InfoRow(label: 'Nome', value: user?.displayName ?? ''),
        _InfoRow(label: 'Email', value: user?.email ?? ''),
        _InfoRow(label: 'Data de nascimento', value: _formatBirth(user?.birthDate)),
        const SizedBox(height: 24),
        GhButton(
          label: 'Alterar palavra-passe',
          secondary: true,
          onPressed: () => _push(const ChangePasswordScreen()),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Os meus dados (exportar)',
          secondary: true,
          onPressed: () => _push(const ExportDataScreen()),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Termos e Condições',
          secondary: true,
          onPressed: () => _push(const LegalViewerScreen(type: 'terms')),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Política de Privacidade',
          secondary: true,
          onPressed: () => _push(const LegalViewerScreen(type: 'privacy')),
        ),
        const SizedBox(height: 28),
        GhButton(
          label: 'Terminar sessão',
          loading: _busy,
          onPressed: () => _logout(everywhere: false),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Terminar sessão em todos os dispositivos',
          secondary: true,
          onPressed: _busy ? null : () => _logout(everywhere: true),
        ),
        const SizedBox(height: 28),
        GhButton(
          label: 'Eliminar conta',
          danger: true,
          secondary: true,
          onPressed: _busy ? null : () => _push(const DeleteAccountScreen()),
        ),
      ],
    );
  }

  /// 2008-03-05 -> 05/03/2008
  static String _formatBirth(String? iso) {
    if (iso == null || iso.length < 10) {
      return '';
    }
    final parts = iso.substring(0, 10).split('-');
    if (parts.length != 3) {
      return iso;
    }
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
