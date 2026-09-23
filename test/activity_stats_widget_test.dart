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
  }) async {
    tester.view.physicalSize = const Size(320, 900);
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
                    activity: activity,
                    elapsedTime: const Duration(minutes: 16),
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
