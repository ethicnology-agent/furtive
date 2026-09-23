import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/widgets/km_milestone_chip.dart';
import 'package:furtive/core/widgets/user_location_puck.dart';

void main() {
  testWidgets(
    'stationary location is a dot; travel and compass remain independent',
    (tester) async {
      Widget subject(double? travel, double? facing) => MaterialApp(
        home: Center(
          child: UserLocationPuck(
            headingDegrees: travel,
            deviceHeading: facing,
          ),
        ),
      );
      await tester.pumpWidget(subject(null, null));
      expect(find.byIcon(Icons.navigation_rounded), findsNothing);
      expect(
        tester.getSize(find.byType(UserLocationPuck)),
        UserLocationPuck.size,
      );
      await tester.pumpWidget(subject(90, 180));
      expect(find.byIcon(Icons.navigation_rounded), findsNWidgets(2));
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(UserLocationPuck),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(
        transform.transform.storage[0],
        closeTo(math.cos(math.pi / 2), 0.00001),
      );
      final paint = find.descendant(
        of: find.byType(UserLocationPuck),
        matching: find.byType(CustomPaint),
      );
      final previous = tester.widget<CustomPaint>(paint).painter!;
      await tester.pumpWidget(subject(90, 270));
      final changed = tester.widget<CustomPaint>(paint).painter!;
      expect(changed.shouldRepaint(previous), isTrue);
      expect(changed.shouldRepaint(changed), isFalse);
      await tester.pumpWidget(subject(null, 270));
      expect(find.byIcon(Icons.navigation_rounded), findsNothing);
      expect(paint, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'kilometre labels stay inside their fixed map badges at large text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: const Center(
              child: SizedBox.square(
                dimension: 32,
                child: KmMilestoneChip(label: '12'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(find.text('12'))),
        TextScaler.noScaling,
      );
      expect(tester.getSize(find.text('12')).width, lessThan(32));
      expect(tester.takeException(), isNull);
    },
  );
}
