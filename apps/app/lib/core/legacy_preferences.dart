import 'package:furtive/core/database/local_database.dart';
import 'package:furtive/core/database/tables/activities_table.dart';
import 'package:furtive/core/database/tables/preferences_table.dart';
import 'package:activity_profile/activity_profile.dart';
import 'package:preferences/preferences.dart';

/// Reads the settings row that predates the preferences database.
///
/// Until furtive 1.4 the settings lived in the recording database, beside
/// every GPS fix. They now have their own store, and this is the bridge: the
/// application is the only component allowed to know both, so the handover
/// happens here rather than inside either module.
///
/// Expand, not contract. The old table is still created, still migrated and
/// still written by nothing — removing it is a destructive step and belongs
/// to a later release than the one that stops reading from it. This whole
/// file goes with it.
class LegacyPreferences {
  LegacyPreferences(this.db);

  final LocalDatabase db;

  /// The settings as they were stored, or null if the row never existed.
  Future<PreferencesEntity?> read() async {
    final row = await (db.select(
      db.preferences,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    return PreferencesEntity(
      mapTheme: _theme(row.mapTheme),
      hasCompletedOnboarding: row.hasCompletedOnboarding,
      uiLocale: row.uiLocale,
      lastShownChangelogVersion: row.lastShownChangelogVersion,
      mapTilesEnabled: row.mapTilesEnabled,
      showOnLockScreen: row.showOnLockScreen,
      mapControlsOnLeft: row.mapControlsOnLeft,
      mapMilestoneIntervalKm: row.mapMilestoneIntervalKm,
      lastActivityType: _type(row.lastActivityType),
      recordingDetail: _detail(row.recordingDetail),
    );
  }

  // Written out rather than matched on `name`, for the same reason the
  // storage spellings exist at all: a value renamed on one side has to be a
  // compile error, not a surprise on somebody's stored settings.
  static MapThemeEntity _theme(MapThemeColumn stored) => switch (stored) {
    MapThemeColumn.light => MapThemeEntity.light,
    MapThemeColumn.dark => MapThemeEntity.dark,
    MapThemeColumn.white => MapThemeEntity.white,
    MapThemeColumn.grayscale => MapThemeEntity.grayscale,
    MapThemeColumn.black => MapThemeEntity.black,
  };

  static ActivityTypeEntity _type(ActivityTypeColumn stored) =>
      switch (stored) {
        ActivityTypeColumn.walk => ActivityTypeEntity.walk,
        ActivityTypeColumn.run => ActivityTypeEntity.run,
        ActivityTypeColumn.bike => ActivityTypeEntity.bike,
        ActivityTypeColumn.car => ActivityTypeEntity.car,
        ActivityTypeColumn.swim => ActivityTypeEntity.swim,
        ActivityTypeColumn.aircraft => ActivityTypeEntity.aircraft,
        ActivityTypeColumn.other => ActivityTypeEntity.other,
        ActivityTypeColumn.unknown => ActivityTypeEntity.unknown,
      };

  static RecordingDetailEntity _detail(RecordingDetailColumn stored) =>
      switch (stored) {
        RecordingDetailColumn.precise => RecordingDetailEntity.precise,
        RecordingDetailColumn.balanced => RecordingDetailEntity.balanced,
        RecordingDetailColumn.endurance => RecordingDetailEntity.endurance,
      };
}
