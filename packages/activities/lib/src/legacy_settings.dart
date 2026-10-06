import 'local_database.dart';

/// The settings row as the pre-1.4 database stored it.
///
/// Primitives, not enums: what each stored name means is the settings
/// module's knowledge, and this one only has to hand the values over
/// faithfully.
typedef LegacySettings = ({
  String mapTheme,
  bool hasCompletedOnboarding,
  String? uiLocale,
  String? lastShownChangelogVersion,
  bool mapTilesEnabled,
  bool showOnLockScreen,
  bool mapControlsOnLeft,
  int mapMilestoneIntervalKm,
  String lastActivityType,
  String recordingDetail,
});

/// Reads the settings row that predates the preferences database.
///
/// Until 1.4 the settings lived in this database, beside every GPS fix. They
/// have their own store now, and the application carries them across once at
/// startup. Returns null when the row never existed — a fresh install.
///
/// Temporary by construction: this function and the table it reads are
/// deleted together in the release after 1.4, which is when dropping the
/// table becomes safe.
Future<LegacySettings?> readLegacySettings() async {
  final db = LocalDatabase.shared;
  final row = await (db.select(
    db.preferences,
  )..where((t) => t.id.equals(1))).getSingleOrNull();
  if (row == null) return null;
  return (
    mapTheme: row.mapTheme.name,
    hasCompletedOnboarding: row.hasCompletedOnboarding,
    uiLocale: row.uiLocale,
    lastShownChangelogVersion: row.lastShownChangelogVersion,
    mapTilesEnabled: row.mapTilesEnabled,
    showOnLockScreen: row.showOnLockScreen,
    mapControlsOnLeft: row.mapControlsOnLeft,
    mapMilestoneIntervalKm: row.mapMilestoneIntervalKm,
    lastActivityType: row.lastActivityType.name,
    recordingDetail: row.recordingDetail.name,
  );
}
