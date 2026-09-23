import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/datasources/location_gps_data_source.dart';
import 'package:furtive/core/entities/activity_profile.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  final source = LocationGpsDataSource();

  test(
    'Android uses the native provider and keeps continuous tracking alive',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      for (final profile in MovementProfileEntity.values) {
        for (final detail in RecordingDetailEntity.values) {
          final settings =
              source.getLocationSettings(tuning: profile.tuning, detail: detail)
                  as AndroidSettings;
          expect(settings.forceLocationManager, isTrue);
          expect(settings.intervalDuration, profile.tuning.intervalFor(detail));
          expect(settings.timeLimit, isNull);
          expect(settings.distanceFilter, 0);
          expect(settings.foregroundNotificationConfig!.enableWakeLock, isTrue);
          expect(settings.foregroundNotificationConfig!.setOngoing, isTrue);
        }
      }
      expect(
        source
            .getLocationSettings(timeLimit: const Duration(seconds: 12))
            .timeLimit,
        const Duration(seconds: 12),
      );
    },
  );
  test(
    'Apple activity hints follow the movement profile without automatic pause',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      for (final profile in MovementProfileEntity.values) {
        final settings =
            source.getLocationSettings(tuning: profile.tuning) as AppleSettings;
        final expected = switch (profile.tuning.navigationKind) {
          NavigationKind.fitness => ActivityType.fitness,
          NavigationKind.automotive => ActivityType.automotiveNavigation,
          NavigationKind.otherNavigation => ActivityType.otherNavigation,
          NavigationKind.airborne => ActivityType.airborne,
          NavigationKind.other => ActivityType.other,
        };
        expect(settings.activityType, expected);
        expect(settings.pauseLocationUpdatesAutomatically, isFalse);
        expect(settings.allowBackgroundLocationUpdates, isTrue);
      }
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(
        (source.getLocationSettings() as AppleSettings)
            .allowBackgroundLocationUpdates,
        isFalse,
      );
    },
  );
  test(
    'desktop fallback has no Android service or battery requirements',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final settings = source.getLocationSettings();
      expect(settings.accuracy, LocationAccuracy.high);
      expect(settings.distanceFilter, 0);
      expect(settings.timeLimit, isNull);
      expect(await source.isBatteryOptimizationDisabled(), isTrue);
      expect(await source.requestDisableBatteryOptimization(), isTrue);
      expect(await source.getServiceEnabledStream().toList(), isEmpty);
    },
  );
}
