import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Caixa cinzenta a "respirar" enquanto o conteúdo carrega (em vez de um círculo a rodar).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06 + 0.08 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Cartão de torneio "em esqueleto".
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GhColors.fieldFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GhColors.fieldBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 200, height: 20),
          SizedBox(height: 8),
          SkeletonBox(width: 120),
          SizedBox(height: 16),
          SkeletonBox(),
          SizedBox(height: 8),
          SkeletonBox(),
          SizedBox(height: 8),
          SkeletonBox(width: 160),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'A carregar',
      child: Column(children: [for (var i = 0; i < count; i++) const SkeletonCard()]),
    );
  }
}
