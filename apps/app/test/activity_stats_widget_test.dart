import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/entities/activity_entity.dart';
import 'package:furtive/core/entities/position_entity.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/core/widgets/activity_stats_widget.dart';
import 'package:furtive/core/widgets/km_splits_chart.dart';
import 'package:furtive/l10n/app_localizations.dart';

void main() {
  final start = DateTime.utc(2026, 9, 23);
  ActivityPointEntity point(int minute, ActivityPointStatusEntity status) =>
      ActivityPointEntity(
        position: PositionEntity(
          latitude: 48 + minute * 0.001,
          longitude: 2,
          elevation: 0,
        ),
        time: start.add(Duration(minutes: minute)),
        status: status,
      );
  final activity = ActivityEntity(
    id: 'stats',
    name: 'Track',
    description: '',
    createdAt: start,
    startedAt: start,
    stoppedAt: start.add(const Duration(minutes: 16)),
    points: [
      point(0, ActivityPointStatusEntity.active),
      point(10, ActivityPointStatusEntity.active),
      point(11, ActivityPointStatusEntity.paused),
      point(16, ActivityPointStatusEntity.paused),
    ],
  );

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    Locale locale = const Locale('en'),
    Size size = const Size(320, 900),
    ActivityEntity? subjectActivity,
    bool isCurrentlyPaused = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ColoredBox(
              color: AppColors.tertiary.background,
              child: Column(
                children: [
                  ActivityStatsWidget(
                    activity: subjectActivity ?? activity,
                    elapsedTime: const Duration(minutes: 16),
                    isCurrentlyPaused: isCurrentlyPaused,
                  ),
                  KmSplitsChart(activity: activity),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('active and paused durations have explicit selectable labels', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('10m00s'), findsOneWidget);
    expect(find.text('16m00s'), findsOneWidget);
    await tester.tap(find.text('Pauses'));
    await tester.pumpAndSettle();
    expect(find.text('05m00s'), findsOneWidget);
    expect(find.text('10m00s'), findsNothing);
  });

  testWidgets('pause selector appears only once a pause exists', (
    tester,
  ) async {
    final uninterrupted = ActivityEntity(
      id: 'uninterrupted',
      name: 'Track',
      description: '',
      createdAt: start,
      startedAt: start,
      stoppedAt: start.add(const Duration(minutes: 10)),
      points: [
        point(0, ActivityPointStatusEntity.active),
        point(10, ActivityPointStatusEntity.active),
      ],
    );

    await pump(tester, subjectActivity: uninterrupted);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Pauses'), findsNothing);

    await pump(tester, subjectActivity: uninterrupted, isCurrentlyPaused: true);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Pauses'), findsOneWidget);
  });

  testWidgets(
    'live statistics use aligned columns and a compact elapsed time',
    (tester) async {
      await pump(
        tester,
        locale: const Locale('fr'),
        size: const Size(393, 844),
      );

      final distanceX = tester.getTopLeft(find.text('DISTANCE')).dx;
      final speedX = tester.getTopLeft(find.text('VITESSE')).dx;
      expect(speedX, closeTo(distanceX, 0.1));

      final durationX = tester.getTopLeft(find.text('DURÉE')).dx;
      final paceX = tester.getTopLeft(find.text('ALLURE')).dx;
      final elevationX = tester.getTopLeft(find.text('DÉNIVELÉ')).dx;
      expect(paceX, closeTo(durationX, 0.1));
      expect(elevationX, closeTo(durationX, 0.1));

      final elapsed = tester.widget<Text>(find.text('16m00s'));
      expect(elapsed.style?.fontSize, lessThanOrEqualTo(32));
    },
  );

  testWidgets('French stats and chart fit a narrow viewport at large text', (
    tester,
  ) async {
    await pump(tester, scale: 2, locale: const Locale('fr'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Pauses'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
