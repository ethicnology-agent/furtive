import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/entities/activity_profile.dart';
import 'package:furtive/core/widgets/hold_to_confirm_button.dart';
import 'package:furtive/features/map/pages/map_recording_controls.dart';
import 'package:furtive/l10n/app_localizations.dart';

void main() {
  Widget subject({
    bool recording = false,
    bool paused = false,
    bool starting = false,
    bool following = false,
    bool hasLocation = true,
    Locale locale = const Locale('en'),
    VoidCallback? onFollow,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(
      floatingActionButton: MapRecordingControls(
        isRecording: recording,
        isPaused: paused,
        isStarting: starting,
        isFollowing: following,
        hasLocation: hasLocation,
        activityType: ActivityTypeEntity.unknown,
        onFollow: onFollow ?? () {},
        onStart: () {},
        onPause: () {},
        onStop: () {},
        onPickType: () {},
        shareControl: FloatingActionButton.extended(
          heroTag: 'share',
          onPressed: () {},
          label: const Text('Share'),
        ),
      ),
    ),
  );

  testWidgets('Stop stays above Follow while active and paused', (
    tester,
  ) async {
    final primary = find.byKey(const ValueKey('recording-primary'));
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();
    final startRect = tester.getRect(primary);
    expect(find.text('Start'), findsOneWidget);
    expect(tester.getRect(find.text('Share')).bottom, lessThan(startRect.top));

    await tester.pumpWidget(subject(recording: true));
    await tester.pumpAndSettle();
    final pauseRect = tester.getRect(primary);
    expect(pauseRect.right, startRect.right);
    expect(pauseRect.top, startRect.top);
    expect(pauseRect.bottom, startRect.bottom);
    expect(find.text('Pause'), findsOneWidget);
    final activeStopRect = tester.getRect(find.byType(HoldToConfirmButton));
    final activeFollowRect = tester.getRect(
      find.widgetWithText(FloatingActionButton, 'Follow'),
    );
    expect(activeFollowRect.top - activeStopRect.bottom, closeTo(16, 0.001));
    expect(activeStopRect.bottom, lessThan(activeFollowRect.top));

    await tester.pumpWidget(subject(recording: true, paused: true));
    await tester.pumpAndSettle();
    final resumeRect = tester.getRect(primary);
    expect(resumeRect.right, startRect.right);
    expect(resumeRect.top, startRect.top);
    expect(resumeRect.bottom, startRect.bottom);
    expect(find.text('Resume'), findsOneWidget);
    final stopRect = tester.getRect(find.byType(HoldToConfirmButton));
    final followRect = tester.getRect(
      find.widgetWithText(FloatingActionButton, 'Follow'),
    );
    expect(followRect.top - stopRect.bottom, closeTo(16, 0.001));
    expect(stopRect.bottom, lessThan(followRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('control width follows the largest visible localized label', (
    tester,
  ) async {
    await tester.pumpWidget(subject(recording: true, paused: true));
    await tester.pumpAndSettle();

    final controlsRect = tester.getRect(find.byType(MapRecordingControls));
    expect(
      tester.getRect(find.byType(HoldToConfirmButton)).width,
      controlsRect.width,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('recording-primary'))).width,
      controlsRect.width,
    );

    await tester.pumpWidget(subject(recording: true, hasLocation: false));
    await tester.pumpAndSettle();
    final waitingWidth = tester
        .getRect(find.byType(MapRecordingControls))
        .width;
    expect(waitingWidth, greaterThan(controlsRect.width));

    await tester.pumpWidget(
      subject(
        recording: true,
        paused: true,
        following: true,
        locale: const Locale('fr', 'CA'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Suivi actif'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Follow is disabled without a fix and names its selected state', (
    tester,
  ) async {
    var follows = 0;
    await tester.pumpWidget(
      subject(hasLocation: false, onFollow: () => follows++),
    );
    await tester.pumpAndSettle();
    final waiting = find.widgetWithText(
      FloatingActionButton,
      'Waiting for GPS',
    );
    expect(tester.widget<FloatingActionButton>(waiting).onPressed, isNull);
    expect(follows, 0);

    await tester.pumpWidget(subject(following: true));
    await tester.pumpAndSettle();
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('starting disables the primary action and shows progress', (
    tester,
  ) async {
    await tester.pumpWidget(subject(starting: true));
    await tester.pump();
    final primary = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('recording-primary')),
    );
    expect(primary.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
