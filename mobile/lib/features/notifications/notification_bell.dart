import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth_scope.dart';
import 'notifications_repository.dart';
import 'notifications_screen.dart';

/// Sino (só o desenho) com o pontinho vermelho quando há notificações novas.
class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({super.key, required this.hasUnread, required this.onPressed});

  final bool hasUnread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hasUnread ? 'Notificações, há novas' : 'Notificações',
      button: true,
      child: IconButton(
        tooltip: 'Notificações',
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none, size: 26),
            if (hasUnread)
              Positioned(
                right: 1,
                top: 0,
                child: Container(
                  key: const ValueKey('notification-dot'),
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF16165F), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sino ligado à API: vai perguntando de tempos a tempos se há notificações novas e abre a central.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.onReturn, this.pollEvery = const Duration(seconds: 45)});

  /// Chamado quando o utilizador volta da central (por exemplo, para recarregar "Os meus torneios").
  final VoidCallback? onReturn;
  final Duration pollEvery;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with WidgetsBindingObserver {
  late NotificationsRepository _repo;
  Timer? _timer;
  bool _started = false;
  int _unread = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _repo = NotificationsRepository(AuthScope.of(context).api);
      WidgetsBinding.instance.addObserver(this);
      _refresh();
      _timer = Timer.periodic(widget.pollEvery, (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  /// Falhas de rede só ficam no log: o pontinho simplesmente não muda.
  Future<void> _refresh() async {
    try {
      final n = await _repo.unreadCount();
      if (mounted && n != _unread) {
        setState(() => _unread = n);
      }
    } catch (e) {
      debugPrint('[GameHall] contagem de notificações falhou: $e');
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) {
      return;
    }
    await _refresh();
    widget.onReturn?.call();
  }

  @override
  Widget build(BuildContext context) => NotificationBellIcon(hasUnread: _unread > 0, onPressed: _open);
}
