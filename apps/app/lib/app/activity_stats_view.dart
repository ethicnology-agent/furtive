import 'package:activities/activities.dart';
import 'package:furtive/l10n/app_localizations.dart';
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

/// The panel's eight labels, in the reader's language.
UiActivityStatsLabels activityStatsLabels(AppLocalizations l10n) =>
    UiActivityStatsLabels(
      elapsed: l10n.statsElapsed,
      active: l10n.statsActive,
      paused: l10n.statsPaused,
      duration: l10n.statDuration,
      distance: l10n.statDistance,
      pace: l10n.statPace,
      speed: l10n.statSpeed,
      elevation: l10n.statElevation,
    );
