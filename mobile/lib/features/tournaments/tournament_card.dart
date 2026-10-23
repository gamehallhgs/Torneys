import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'tournament_models.dart';

class TournamentCard extends StatelessWidget {
  const TournamentCard({super.key, required this.tournament, required this.onTap});

  final TournamentSummary tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tournament;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GhColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(status: t.status),
                        if (t.showFullFlag) ...[
                          const SizedBox(height: 6),
                          const FullFlag(),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t.organizerName,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(TournamentLabels.sport(t.sport)),
                    _Tag(TournamentLabels.format(t.format)),
                    _Tag('${t.ageLabel} anos'),
                  ],
                ),
                const SizedBox(height: 12),
                _Line(Icons.calendar_today, Fmt.dateRange(t.startsOn, t.endsOn)),
                _Line(Icons.place_outlined, t.placeLine),
                _Line(
                  Icons.groups_outlined,
                  TournamentLabels.teamsLine(t.teamsConfirmed, t.maxTeams, t.teamsInFormation),
                ),
                _Line(Icons.euro, '${Fmt.money(t.entryFeeCents)} por equipa'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta laranja "Cheio": todas as vagas têm equipas confirmadas.
class FullFlag extends StatelessWidget {
  const FullFlag({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Torneio cheio',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: GhColors.full.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: GhColors.full),
        ),
        child: const Text(
          'Cheio',
          style: TextStyle(color: GhColors.full, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'registration_open' => GhColors.success,
      'ongoing' => const Color(0xFFFFC857),
      'registration_closed' => const Color(0xFFFFA07A),
      _ => Colors.white70,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        TournamentLabels.status(status),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: GhColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
