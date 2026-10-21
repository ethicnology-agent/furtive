import 'package:activities/legacy.dart';
import 'package:activity_profile/activity_profile.dart';
import 'package:preferences/preferences.dart';

/// Carries the settings that predate the preferences database across.
///
/// Until furtive 1.4 the settings were a row in the recording database,
/// beside every GPS fix. They have their own store now, and this is the
/// bridge: the application is the only component allowed to know both, so
/// the translation between them happens here rather than inside either.
///
/// Expand, not contract. The old table is still created and still migrated;
/// removing it is destructive and belongs to a later release than the one
/// that stops reading from it. This file goes with it.
class LegacyPreferences {
  const LegacyPreferences();

  /// The settings as they were stored, or null if the row never existed.
  Future<PreferencesEntity?> read() async {
    final stored = await readLegacySettings();
    if (stored == null) return null;
    return PreferencesEntity(
      mapTheme: _theme(stored.mapTheme),
      hasCompletedOnboarding: stored.hasCompletedOnboarding,
      uiLocale: stored.uiLocale,
      lastShownChangelogVersion: stored.lastShownChangelogVersion,
      mapTilesEnabled: stored.mapTilesEnabled,
      showOnLockScreen: stored.showOnLockScreen,
      mapControlsOnLeft: stored.mapControlsOnLeft,
      mapMilestoneIntervalKm: stored.mapMilestoneIntervalKm,
      lastActivityType: _type(stored.lastActivityType),
      recordingDetail: _detail(stored.recordingDetail),
    );
  }

  // Matched on the stored name, which is safe only because the schema being
  // read is frozen: it will never gain a value, so there is no future
  // spelling to forget. Each falls back rather than throwing — one
  // unreadable field must not cost a user every other setting they chose.
  static MapThemeEntity _theme(String stored) =>
      MapThemeEntity.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => MapThemeEntity.dark,
      );

  static ActivityTypeEntity _type(String stored) =>
      ActivityTypeEntity.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => ActivityTypeEntity.walk,
      );

  static RecordingDetailEntity _detail(String stored) =>
      RecordingDetailEntity.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => RecordingDetailEntity.balanced,
      );
}
