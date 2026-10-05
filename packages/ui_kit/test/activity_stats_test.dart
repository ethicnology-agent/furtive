import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

const labels = UiActivityStatsLabels(
  elapsed: 'ELAPSED',
  active: 'Active',
  paused: 'Paused',
  duration: 'Duration',
  distance: 'Distance',
  pace: 'Pace',
  speed: 'Speed',
  elevation: 'Elevation',
);

const active = UiActivityStats(
  duration: Duration(minutes: 30),
  distanceKm: 5.25,
  pace: '5:43',
  speedKmh: 10.5,
);

const paused = UiActivityStats(
  duration: Duration(minutes: 4),
  distanceKm: 0.01,
  pace: '--',
  speedKmh: 0.15,
);

void main() {
  Future<void> show(
    WidgetTester tester, {
    bool hasPausedSegments = false,
    bool isCurrentlyPaused = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityStatsWidget(
              active: active,
              paused: paused,
              activeElevationGainMeters: 128.4,
              elapsedTime: const Duration(minutes: 34),
              labels: labels,
              hasPausedSegments: hasPausedSegments,
              isCurrentlyPaused: isCurrentlyPaused,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the active figures and the elapsed clock', (tester) async {
    await show(tester);

    expect(find.text('34m00s'), findsOneWidget);
    expect(find.text('30m00s'), findsOneWidget);
    expect(find.text('5.25 km'), findsOneWidget);
    expect(find.text('5:43 /km'), findsOneWidget);
    expect(find.text('10.50 km/h'), findsOneWidget);
    expect(find.text('128 m'), findsOneWidget);
  });

  testWidgets('every label comes from the caller', (tester) async {
    await show(tester);

    for (final label in ['ELAPSED', 'DURATION', 'DISTANCE', 'PACE', 'SPEED']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('no selector until the recording has been paused', (
    tester,
  ) async {
    await show(tester);

    expect(find.text('Active'), findsNothing);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('a pause that has just begun already shows the selector', (
    tester,
  ) async {
    // The first paused segment does not exist yet, but the user is paused
    // right now and the choice belongs on screen.
    await show(tester, isCurrentlyPaused: true);

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('a past pause keeps the selector after resuming', (tester) async {
    await show(tester, hasPausedSegments: true);

    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('choosing paused swaps every figure', (tester) async {
    await show(tester, hasPausedSegments: true);

    await tester.tap(find.text('Paused'));
    await tester.pumpAndSettle();

    expect(find.text('04m00s'), findsOneWidget);
    expect(find.text('0.01 km'), findsOneWidget);
    expect(find.text('-- /km'), findsOneWidget);
    expect(find.text('0.15 km/h'), findsOneWidget);
  });

  testWidgets('elevation is hidden while showing paused figures', (
    tester,
  ) async {
    // Elevation gained while paused is not gain anyone climbed, so the row
    // reports the active figure or nothing at all.
    await show(tester, hasPausedSegments: true);
    expect(find.text('128 m'), findsOneWidget);

    await tester.tap(find.text('Paused'));
    await tester.pumpAndSettle();

    expect(find.text('128 m'), findsNothing);
    expect(find.text('ELEVATION'), findsNothing);
  });

  testWidgets('the opaque background is opt-in', (tester) async {
    // Material paints ColoredBox of its own, so look for the black one the
    // panel adds when a caller needs the map hidden behind it.
    final blackBox = find.byWidgetPredicate(
      (widget) => widget is ColoredBox && widget.color == Colors.black,
    );
    await show(tester);
    expect(blackBox, findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivityStatsWidget(
              active: active,
              paused: paused,
              activeElevationGainMeters: 128.4,
              elapsedTime: const Duration(minutes: 34),
              labels: labels,
              opaqueBackground: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(blackBox, findsOneWidget);
  });
}
