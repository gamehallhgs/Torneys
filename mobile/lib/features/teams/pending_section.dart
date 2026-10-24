import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'team_models.dart';
import 'team_widgets.dart';

/// Pedidos para entrar enviados, no topo de "Os meus torneios". Os convites recebidos ficam nas notificações.
class PendingSection extends StatelessWidget {
  const PendingSection({
    super.key,
    required this.requests,
    required this.busy,
    required this.onOpen,
    required this.onCancelRequest,
  });

  final List<MyInvolvement> requests;
  final bool busy;
  final void Function(String teamId) onOpen;
  final void Function(String requestId) onCancelRequest;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
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
