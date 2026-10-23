import 'package:flutter/material.dart';

/// Renderizador mínimo de Markdown (títulos, listas e parágrafos), suficiente para os
/// documentos legais. Evita depender de pacotes de Markdown descontinuados.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.text, {super.key});

  final String text;

  static String _inline(String line) => line
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => '${m[1]} (${m[2]})')
      .replaceAll('`', '');

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final size = level == 1 ? 22.0 : (level == 2 ? 18.0 : 16.0);
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            _inline(heading.group(2)!),
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w800),
          ),
        ));
        continue;
      }
      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(_inline(bullet.group(1)!))),
            ],
          ),
        ));
        continue;
      }
      widgets.add(Text(_inline(line), style: const TextStyle(height: 1.4)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
