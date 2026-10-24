import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamehall_torneios/features/tournaments/chip_tabs_row.dart';

const tabs = <(String, String)>[
  ('open', 'Abertos'),
  ('ongoing', 'A decorrer'),
  ('finished', 'Terminados'),
  ('mine', 'Os meus torneios'),
];

Widget host({required double width, required ValueChanged<String> onSelected, String selected = 'open'}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ChipTabsRow(
              tabs: tabs,
              selected: selected,
              onSelected: onSelected,
              trailing: const Icon(Icons.notifications_none, key: ValueKey('bell')),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('largo: todos os separadores e o sino cabem, sem esbater', (tester) async {
    await tester.pumpWidget(host(width: 700, onSelected: (_) {}));
    await tester.pump();
    for (final t in tabs) {
      expect(find.text(t.$2), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('bell')), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
  });

  testWidgets('estreito: desliza e o fim esbate-se; o sino fica sempre visível', (tester) async {
    await tester.pumpWidget(host(width: 300, onSelected: (_) {}));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ShaderMask), findsWidgets);
    expect(find.byKey(const ValueKey('bell')), findsOneWidget);
    final bell = tester.getRect(find.byKey(const ValueKey('bell')));
    final lastChip = tester.getRect(find.byType(ChoiceChip).first);
    expect(lastChip.right, lessThanOrEqualTo(bell.left + 1));
  });

  testWidgets('tocar num separador escolhe-o', (tester) async {
    String? picked;
    await tester.pumpWidget(host(width: 700, onSelected: (v) => picked = v));
    await tester.tap(find.text('Os meus torneios'));
    await tester.pump();
    expect(picked, 'mine');
  });
}
