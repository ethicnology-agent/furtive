import 'package:activity_profile/activity_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  late ActivityTypeEntity? result;

  Future<void> open(
    WidgetTester tester, {
    ActivityTypeEntity selected = ActivityTypeEntity.walk,
    String Function(ActivityTypeEntity)? labelFor,
  }) async {
    result = null;
    // The default 800x600 surface is shorter than a seven-entry sheet, and a
    // ListView does not build what it cannot show — the last type would be
    // absent from the tree rather than merely off screen.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showActivityTypePicker(
                  context,
                  selected: selected,
                  title: 'Pick an activity',
                  labelFor: labelFor ?? (type) => type.name.toUpperCase(),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every selectable type and no others', (tester) async {
    await open(tester);

    for (final type in selectableActivityTypes) {
      expect(find.text(type.name.toUpperCase()), findsOneWidget);
    }
    expect(
      find.text(ActivityTypeEntity.unknown.name.toUpperCase()),
      findsNothing,
      reason: 'unknown exists for imports, never as a choice',
    );
  });

  testWidgets('labels come from the caller, not from the kit', (tester) async {
    await open(tester, labelFor: (type) => 'Activité ${type.index}');

    expect(find.text('Activité 0'), findsOneWidget);
    expect(find.text('walk'), findsNothing);
  });

  testWidgets('shows the title as a header for a screen reader', (
    tester,
  ) async {
    await open(tester);

    expect(
      tester.getSemantics(find.text('Pick an activity')),
      matchesSemantics(label: 'Pick an activity', isHeader: true),
    );
  });

  testWidgets('checks the current selection and nothing else', (tester) async {
    await open(tester, selected: ActivityTypeEntity.bike);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('BIKE'), matching: find.byType(ListTile)),
    );
    expect(tile.selected, isTrue);
  });

  testWidgets('returns the chosen type', (tester) async {
    await open(tester);

    await tester.tap(find.text('RUN'));
    await tester.pumpAndSettle();

    expect(result, ActivityTypeEntity.run);
  });

  testWidgets('returns null when dismissed', (tester) async {
    await open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('every type has an icon, including unknown', (tester) async {
    for (final type in ActivityTypeEntity.values) {
      expect(() => activityTypeIcon(type), returnsNormally);
    }
  });
}
