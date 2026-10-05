import 'package:drift/drift.dart';

@DataClassName('ActivitiesRow')
// Indexed on startedAt because the activities list page sorts by it on
// every fetch; without the index the table scans the whole activities
// table on every refresh.
@TableIndex(name: 'idx_activities_started_at', columns: {#startedAt})
// Indexed on stoppedAt because fetchOngoing() filters on `stoppedAt IS NULL` on
// every cold start (and again for each orphan it reconciles). Without it that is
// a full table scan; a partial index is not expressible here, but SQLite uses
// this one for the IS NULL probe.
@TableIndex(name: 'idx_activities_stopped_at', columns: {#stoppedAt})
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get stoppedAt => dateTime().nullable()();
  // Recording commands are durable independently of GPS reception. NULL
  // completed-pause time identifies legacy rows whose state must be inferred
  // from points. Milliseconds preserve the pause instant across restarts.
  IntColumn get recordingPausedAtMs => integer().nullable()();
  IntColumn get recordingCompletedPauseMs => integer().nullable()();
  // Denormalised aggregates so the activities list can render distance/pace
  // without loading every point of every activity. -1 = not yet computed
  // (legacy rows backfilled lazily on first list fetch; live/in-progress rows
  // computed on the fly until ceased).
  RealColumn get distanceMeters => real().withDefault(const Constant(-1))();
  IntColumn get activeDurationMs => integer().withDefault(const Constant(-1))();
  // What the user was doing. Recorded at start and kept for the life of the
  // activity, because it is what sized the GPS sampling and the quality gate
  // that produced these very points — changing the preference later must not
  // retroactively reinterpret an old recording.
  //
  // Defaults to `unknown` rather than `walk`: rows predating this column, and
  // GPX imports whose file carries no usable type, genuinely are unknown, and
  // guessing would silently restate what a past recording meant. `unknown`
  // maps to the permissive generic movement profile.
  TextColumn get activityType =>
      textEnum<ActivityTypeColumn>().withDefault(const Constant('unknown'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Storage spelling of ActivityTypeEntity. Duplicated rather than reusing the
/// entity so a rename in the domain layer cannot silently rewrite what is
/// already on disk — same reason ActivityPointsStatusColumn exists.
/// Adding a value here needs no migration — drift stores the name in a plain
/// TEXT column with no CHECK constraint. **Removing** one does: any stored row
/// still holding it stops mapping back to an enum and fails on read, so a
/// removal must be paired with a migration rewriting those rows (see the v14
/// step in local_database.dart).
enum ActivityTypeColumn { walk, run, bike, car, swim, aircraft, other, unknown }
