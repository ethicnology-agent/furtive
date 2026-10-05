import 'preferences_database.dart';
import 'preferences_entity.dart';
import 'preferences_local_data_source.dart';
import 'preferences_model.dart';

/// Entity-level access to the application's settings.
class PreferencesRepository {
  /// The settings, in this module's own database.
  PreferencesRepository() : this._(_shared ??= PreferencesDatabase());

  /// An isolated in-memory store, for tests. Each call gets its own.
  PreferencesRepository.inMemory() : this._(PreferencesDatabase.memory());

  PreferencesRepository._(this._database)
    : _local = PreferencesLocalDataSource(_database);

  /// One connection per process. Settings are read from several places at
  /// startup and the file is tiny; opening one database per caller would
  /// cost a connection each for no isolation anyone wants.
  static PreferencesDatabase? _shared;

  final PreferencesDatabase _database;
  final PreferencesLocalDataSource _local;

  /// Closes the store.
  ///
  /// An in-memory store belongs to whoever created it and should be closed
  /// with it. The process-wide one lives as long as the process; closing it
  /// leaves every other repository holding a closed database, so only its
  /// owner should.
  Future<void> close() => _database.close();

  Future<void> store(PreferencesEntity preferences) async {
    await _local.store(PreferencesModel.fromEntity(preferences));
  }

  /// The stored settings, or the defaults when nothing has been stored.
  ///
  /// Reading never writes. A caller that wants the defaults persisted has to
  /// [store] them.
  Future<PreferencesEntity> fetch() async {
    final row = await _local.fetchRow();
    return PreferencesModel.toEntity(
      row == null ? PreferencesModel.defaults : PreferencesModel.fromRow(row),
    );
  }

  /// Takes [preferences] over, but only if nothing has ever been stored here.
  ///
  /// This is how settings that predate this database arrive. It is
  /// deliberately refusable: running it twice, or after a user has changed
  /// anything, must not overwrite what they chose. Returns whether the
  /// handover happened.
  Future<bool> adoptIfEmpty(PreferencesEntity preferences) async {
    if (await _local.hasStoredRow) return false;
    await store(preferences);
    return true;
  }
}
