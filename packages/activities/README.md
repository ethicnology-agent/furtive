# activities

Recorded activities: their points, the statistics derived from them, and the
database they live in.

## When to use it

Whenever a screen needs a recording — to list them, to show one, to score
one at the end. Reach for `ActivityRepository`; it is the whole contract.

What a recording *is* lives here. What a user *does* with one does not:
importing and exporting GPX, rendering a share card and sharing it are
journeys, and they live in the feature that offers them.

## Example

```dart
final activities = ActivityRepository();
final recent = await activities.fetchSummaries(limit: 20);
final full = await activities.fetch(recent.first.id);
```

## Owned and borrowed

Owned: `app.sqlite` in the documents directory, the activities and points
tables, their migrations, and one connection for the life of the process.
Borrowed: a `Clock`, which every constructor defaults to the real one so
production call sites stay terse and a test can drive the twelve-hour
stale-recording window without waiting it out.

## Three libraries, on purpose

`package:activities/activities.dart` is the contract: the entity, the
summary, the repository, the scoring. Nothing in it mentions drift.

`package:activities/testing.dart` is the seam tests drive the module
through, and production code must not import it. It exposes the database and
the row-level datasource so a test can seed a recording directly, and
`LocalDatabase.installSharedForTesting` so the default call sites — the ones
that stay `ActivityRepository()` in production — read an in-memory database
instead of the real file.

`package:activities/legacy.dart` is the one-time bridge out of the pre-1.4
layout: the settings used to be a row in this database, and `readLegacySettings`
hands them over as primitives. It is deleted with the table it reads, in the
release after 1.4.

## Guarantees

Almost nothing a screen shows is stored. Distance, duration, pace, elevation
gain and kilometre splits are derived from the points, which are split into
segments by what the recorder was doing — moving, paused, or without signal.
A paused stretch is excluded from the active figures; a signal gap is
bracketed rather than bridged, so an outage is never counted as distance
travelled.

Every instant stored is UTC. Reading one back is a different matter: drift
returns a DateTime flagged **local**, carrying the right instant with the
wrong flag. Comparisons are unaffected — `isBefore`, `difference` and
`isAtSameMomentAs` all work across flags — but anything that serialises has
to call `toUtc()` first, which the GPX export does on every timestamp it
writes.

The schema refuses to open a database stamped with a newer version than it
knows, rather than letting drift stamp the lower number over a schema that
has already moved on. Every migration runs inside one transaction, so a
process killed mid-upgrade retries cleanly instead of replaying statements
against columns that already exist.

## Verification

`test/database_test.dart` covers the migrations from every shipped schema,
the fresh-database path, the foreign key that cascades, pagination, and the
recovery of a recording interrupted by a process kill.
`test/activity_repository_test.dart` covers the contract above it: starting,
ceasing, renaming and deleting, that the activity type is stamped once and
never revised, scoring, checkpoints, live aggregates, summary pagination,
and the local-flag round trip.
`test/activity_stats_test.dart` covers the figures derived from points.
