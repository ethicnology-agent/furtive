import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

Widget host(Widget child) => MaterialApp(
  theme: appTheme,
  home: Scaffold(body: child),
);

Text textOf(WidgetTester tester, String data) =>
    tester.widget<Text>(find.text(data));

void main() {
  testWidgets('the full density shows the label in caps above the value', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const StatBlock(icon: Icons.timer, label: 'Duration', value: '12:34'),
      ),
    );

    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
  });

  testWidgets('the compact density drops the label from the layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const StatBlock.compact(
          icon: Icons.timer,
          label: 'Duration',
          value: '12:34',
        ),
      ),
    );

    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('DURATION'), findsNothing);
    expect(find.text('Duration'), findsNothing);
  });

  testWidgets('the compact density keeps the label for a screen reader', (
    tester,
  ) async {
    // The label is dropped visually for space, not dropped from the
    // information: read aloud, "12:34" alone says nothing.
    await tester.pumpWidget(
      host(
        const StatBlock.compact(
          icon: Icons.timer,
          label: 'Duration',
          value: '12:34',
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(StatBlock)),
      matchesSemantics(label: 'Duration: 12:34'),
    );
  });

  testWidgets('a value with no label reads as itself', (tester) async {
    await tester.pumpWidget(
      host(const StatBlock.compact(icon: Icons.timer, value: '12:34')),
    );

    expect(
      tester.getSemantics(find.byType(StatBlock)),
      matchesSemantics(label: '12:34'),
    );
  });

  testWidgets('emphasis recolours the value, and nothing else does', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const StatBlock(icon: Icons.timer, label: 'Duration', value: '12:34'),
      ),
    );
    expect(textOf(tester, '12:34').style?.color, Colors.white);

    await tester.pumpWidget(
      host(
        const StatBlock(
          icon: Icons.timer,
          label: 'Duration',
          value: '12:34',
          emphasize: true,
        ),
      ),
    );
    expect(textOf(tester, '12:34').style?.color, kMint);
  });

  testWidgets('figures are tabular so columns of stats line up', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const StatBlock(icon: Icons.timer, label: 'Duration', value: '12:34'),
      ),
    );

    expect(textOf(tester, '12:34').style?.fontFeatures, kTabularFigures);
  });
}
