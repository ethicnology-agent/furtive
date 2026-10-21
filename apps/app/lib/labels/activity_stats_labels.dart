import 'package:furtive/l10n/app_localizations.dart';
import 'package:ui_kit/ui_kit.dart';

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
