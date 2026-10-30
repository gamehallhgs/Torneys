import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_scope.dart';
import '../../core/error_messages.dart';
import '../../widgets/gh_widgets.dart';
import '../auth/screens/legal_viewer_screen.dart';
import '../onboarding/welcome_guide_screen.dart';
import 'change_name_screen.dart';
import 'change_password_screen.dart';
import 'change_username_screen.dart';
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
        // O email não se mostra no perfil (nem aos outros jogadores): só o nome e o username.
        _InfoRow(label: 'Nome', value: user?.displayName ?? ''),
        _HandleRow(handle: user?.handle ?? ''),
        _InfoRow(label: 'Data de nascimento', value: _formatBirth(user?.birthDate)),
        const SizedBox(height: 16),
        const PushSwitchTile(),
        const SizedBox(height: 16),
        GhButton(
          label: 'Mudar nome',
          secondary: true,
          onPressed: () => _push(const ChangeNameScreen()),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Mudar username',
          secondary: true,
          onPressed: () => _push(const ChangeUsernameScreen()),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Alterar palavra-passe',
          secondary: true,
          onPressed: () => _push(const ChangePasswordScreen()),
        ),
        const SizedBox(height: 12),
        GhButton(
          label: 'Ver guia',
          secondary: true,
          onPressed: () => _push(const WelcomeGuideScreen()),
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

/// "@hugo#482" com botão para copiar (é o que os amigos escrevem para te convidar).
class _HandleRow extends StatelessWidget {
  const _HandleRow({required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Username', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 2),
                Text(handle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                const Text(
                  'Partilha-o para te convidarem para equipas.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: handle.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: handle.substring(1)));
                    messenger.showSnackBar(const SnackBar(content: Text('Username copiado.')));
                  },
          ),
        ],
      ),
    );
  }
}


/// Interruptor geral das notificações push. Desligar não apaga nada da central de notificações da app.
class PushSwitchTile extends StatefulWidget {
  const PushSwitchTile({super.key});

  @override
  State<PushSwitchTile> createState() => _PushSwitchTileState();
}

class _PushSwitchTileState extends State<PushSwitchTile> {
  bool _busy = false;
  String? _error;

  Future<void> _set(bool value) async {
    final auth = AuthScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.setPushEnabled(value);
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = AuthScope.of(context).user?.pushEnabled ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) GhBanner.error(_error!),
        SwitchListTile(
          key: const ValueKey('push-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Notificações push', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text(
            'Convites, pedidos, vaga reservada, tempo a acabar e jogos. As notificações na app mantêm-se.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          value: enabled,
          onChanged: _busy ? null : _set,
        ),
      ],
    );
  }
}
