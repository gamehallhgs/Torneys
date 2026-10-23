import 'package:flutter/material.dart';

/// Bolinha com a cor da equipa.
class ColorDot extends StatelessWidget {
  const ColorDot(this.color, {super.key, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
      );
}
