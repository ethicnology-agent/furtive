import 'package:drift/drift.dart';

import 'preferences_database.dart';
import 'preferences_model.dart';

/// Reads and writes the single settings row.
class PreferencesLocalDataSource {
  PreferencesLocalDataSource(this.db);

  final PreferencesDatabase db;

  /// The one row this table ever holds.
  static const _rowId = 1;

  Future<void> store(PreferencesModel preferences) async {
    await db
        .into(db.preferences)
        .insertOnConflictUpdate(
          PreferencesCompanion(
            id: const Value(_rowId),
            mapTheme: Value(preferences.mapTheme),
            hasCompletedOnboarding: Value(preferences.hasCompletedOnboarding),
            uiLocale: Value(preferences.uiLocale),
            lastShownChangelogVersion: Value(
              preferences.lastShownChangelogVersion,
            ),
            mapTilesEnabled: Value(preferences.mapTilesEnabled),
            showOnLockScreen: Value(preferences.showOnLockScreen),
            mapControlsOnLeft: Value(preferences.mapControlsOnLeft),
            mapMilestoneIntervalKm: Value(preferences.mapMilestoneIntervalKm),
            lastActivityType: Value(preferences.lastActivityType),
            recordingDetail: Value(preferences.recordingDetail),
          ),
        );
  }

  Future<PreferencesRow?> fetchRow() => (db.select(
    db.preferences,
  )..where((t) => t.id.equals(_rowId))).getSingleOrNull();

  /// Whether anything has ever been stored.
  ///
  /// The row is written by [store] and by nothing else — reading does not
  /// create it. That is what lets the application tell a fresh store from one
  /// a user has already touched, which is the whole basis of the one-time
  /// handover from the recording database.
  Future<bool> get hasStoredRow async => await fetchRow() != null;
}
