import 'package:activities/activities.dart';
import 'package:ui_kit/ui_kit.dart';

/// Reduces a recording to the figures the stats panel shows.
///
/// The panel is in ui_kit because two journeys render it, and a ui module
/// may not reach a business one. This is the seam: the application knows an
/// ActivityEntity, the kit knows four numbers and eight strings.
extension ActivityStatsView on ActivityEntity {
  UiActivityStats get activeStats => UiActivityStats(
    duration: activeDuration,
    distanceKm: activeDistanceInKm,
    pace: activePaceMinPerKm,
    speedKmh: activeSpeedKmh,
  );

  UiActivityStats get pausedStats => UiActivityStats(
    duration: pausedDuration,
    distanceKm: pausedDistanceInKm,
    pace: pausedPaceMinPerKm,
    speedKmh: pausedSpeedKmh,
  );
}
