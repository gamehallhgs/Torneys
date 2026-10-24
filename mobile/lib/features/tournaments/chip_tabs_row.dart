import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Separadores em "chips" (Abertos, A decorrer...) com um widget fixo à direita (o sino das notificações).
/// Os chips são compactos para caberem; se mesmo assim não couberem, deslizam e o fim da lista esbate-se
/// (em vez de o último botão aparecer cortado de repente). O separador escolhido desliza para a vista.
class ChipTabsRow extends StatefulWidget {
  const ChipTabsRow({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  /// (valor, texto)
  final List<(String, String)> tabs;
  final String selected;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  @override
  State<ChipTabsRow> createState() => _ChipTabsRowState();
}

class _ChipTabsRowState extends State<ChipTabsRow> {
  final _controller = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  bool _fadeRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFade);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateFade() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final more = _controller.position.maxScrollExtent - _controller.offset > 4;
    if (more != _fadeRight) {
      setState(() => _fadeRight = more);
    }
  }

  void _select(String value) {
    widget.onSelected(value);
    final ctx = _keys[value]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget chips = SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in widget.tabs) ...[
            ChoiceChip(
              key: _keys.putIfAbsent(tab.$1, () => GlobalKey()),
              label: Text(tab.$2),
              selected: widget.selected == tab.$1,
              onSelected: (_) => _select(tab.$1),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              selectedColor: GhColors.primary,
              backgroundColor: GhColors.fieldFill,
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
              side: const BorderSide(color: GhColors.fieldBorder),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );

    if (_fadeRight) {
      chips = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.88, 1.0],
        ).createShader(rect),
        child: chips,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Depois de cada layout (rodar o ecrã, mudar o tamanho) vê se ainda há chips escondidos.
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateFade());
        return Row(
          children: [
            Expanded(child: chips),
            if (widget.trailing != null) ...[
              const SizedBox(width: 4),
              widget.trailing!,
            ],
          ],
        );
      },
    );
  }
}
