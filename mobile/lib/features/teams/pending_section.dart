import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'team_models.dart';
import 'team_widgets.dart';

/// Convites recebidos e pedidos enviados, no topo de "Os meus torneios".
class PendingSection extends StatelessWidget {
  const PendingSection({
    super.key,
    required this.invites,
    required this.requests,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onDecline,
    required this.onCancelRequest,
  });

  final List<MyInvolvement> invites;
  final List<MyInvolvement> requests;
  final bool busy;
  final void Function(String teamId) onOpen;
  final void Function(String inviteId) onAccept;
  final void Function(String inviteId) onDecline;
  final void Function(String requestId) onCancelRequest;

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty && requests.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invites.isNotEmpty) ...[
            Text('Convites recebidos (${invites.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            for (final i in invites)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ColorDot(i.color, size: 22),
                title: Text(i.teamName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${i.tournamentName}\nConvidado por ${i.invitedByName ?? 'o líder'}'),
                isThreeLine: true,
                onTap: () => onOpen(i.teamId),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Recusar',
                      icon: const Icon(Icons.close, color: GhColors.error),
                      onPressed: busy ? null : () => onDecline(i.id),
                    ),
                    IconButton(
                      tooltip: 'Aceitar',
                      icon: const Icon(Icons.check, color: GhColors.success),
                      onPressed: busy ? null : () => onAccept(i.id),
                    ),
                  ],
                ),
              ),
          ],
          if (invites.isNotEmpty && requests.isNotEmpty) const Divider(color: Colors.white24),
          if (requests.isNotEmpty) ...[
            Text('Pedidos enviados (${requests.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            for (final r in requests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ColorDot(r.color, size: 22),
                title: Text(r.teamName),
                subtitle: Text(r.tournamentName),
                onTap: () => onOpen(r.teamId),
                trailing: TextButton(
                  onPressed: busy ? null : () => onCancelRequest(r.id),
                  child: const Text('Cancelar'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
