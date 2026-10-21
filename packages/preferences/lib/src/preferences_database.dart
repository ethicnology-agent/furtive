import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'preferences_table.dart';

part 'preferences_database.g.dart';

/// The settings database.
///
/// Separate from the recording database on purpose: a module that owns data
/// owns the schema it lives in, and a settings row sharing a file with every
/// GPS fix ever recorded means neither can be migrated, backed up or cleared
/// without reasoning about the other.
///
/// It starts at version 1 even though the settings themselves are older. The
/// rows that predate it are carried over once by the application, which is
/// the only component allowed to know both stores; see the handover in
/// apps/app. The old table is not dropped here or by that handover — a
/// destructive step belongs to a later release than the one that stops
/// reading from it.
@DriftDatabase(tables: [Preferences])
class PreferencesDatabase extends _$PreferencesDatabase {
  PreferencesDatabase() : super(_openConnection());

  /// An isolated in-memory database, for tests.
  PreferencesDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => await m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      // Same refusal as the recording database: drift calls onUpgrade even
      // when `from` is newer, and letting it stamp the lower version into
      // user_version leaves the file describing a schema it does not have.
      if (from > to) {
        throw StateError(
          'Refusing to downgrade preferences schema from v$from to v$to. '
          'Reinstall the version that created this database, or clear app '
          'data to start fresh.',
        );
      }
    },
  );

  /// The file this database lives in, for the caller that excludes it from
  /// platform backups.
  static Future<String> get path async =>
      p.join((await getApplicationDocumentsDirectory()).path, _filename);

  static const _filename = 'preferences.sqlite';
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path, PreferencesDatabase._filename));
    // On the UI isolate deliberately, unlike the recording database: this one
    // holds a single row read once at startup and written when a user flips a
    // switch, so an isolate per process would cost more than it saves.
    return NativeDatabase(file);
  });
}
