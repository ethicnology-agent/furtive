import 'package:activities/activities.dart';
import 'package:activities/testing.dart';
import 'package:activity_profile/activity_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo/geo.dart';
import 'package:wall_clock/wall_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late FixedClock clock;
  late ActivityRepository subject;

  setUp(() {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    clock = FixedClock(DateTime.utc(2026, 9, 24, 10));
    subject = ActivityRepository(
      local: ActivityLocalDataSource(db: db, clock: clock),
      clock: clock,
    );
  });

  tearDown(() => db.close());

  ActivityPointEntity fix(DateTime time, {double lat = 48.8566}) =>
      ActivityPointEntity(
        position: PositionEntity(
          latitude: lat,
          longitude: 2.3522,
          elevation: 35,
          time: time,
        ),
        time: time,
        status: ActivityPointStatusEntity.active,
      );

  test('a new activity is ongoing and stamped from the clock', () async {
    final started = await subject.startNew(
      activityType: ActivityTypeEntity.run,
    );

    expect(started.startedAt, clock.nowUtc());
    expect(started.id, clock.nowUtc().toIso8601String());
    expect(started.stoppedAt, isNull);
    expect(started.activityType, ActivityTypeEntity.run);
    expect((await subject.fetchOngoing())?.id, started.id);
  });

  test('the type is stamped once and never revised', () async {
    // A later preference change must not restate what a past recording was.
    final started = await subject.startNew(
      activityType: ActivityTypeEntity.bike,
    );
    clock.advance(const Duration(hours: 1));
    await subject.startNew(activityType: ActivityTypeEntity.walk);

    expect(
      (await subject.fetchSingle(started.id)).activityType,
      ActivityTypeEntity.bike,
    );
  });

  test('ceasing ends the activity and clears the ongoing slot', () async {
    final started = await subject.startNew();
    clock.advance(const Duration(minutes: 30));

    await subject.cease(started.id);

    expect(await subject.fetchOngoing(), isNull);
    expect((await subject.fetchSingle(started.id)).stoppedAt, isNotNull);
  });

  test('scored points come back as stored, instant for instant', () async {
    // `points` preserves what was written; ordering by time happens when the
    // entity segments them, not on read.
    final started = await subject.startNew();
    final first = clock.nowUtc();

    await subject.score(started.id, [
      fix(first.add(const Duration(seconds: 10)), lat: 48.8570),
      fix(first),
    ]);

    final stored = await subject.fetchSingle(started.id);
    expect(stored.points, hasLength(2));
    expect(stored.points.last.time.isAtSameMomentAs(first), isTrue);
  });

  test(
    'a stored instant survives the round trip, however it is flagged',
    () async {
      // drift hands DateTimes back local-flagged: the right instant with the
      // wrong flag. Comparisons are unaffected, but anything that serialises
      // has to call toUtc() — the GPX export does. Asserted here so a change
      // on either side is noticed rather than discovered in an exported file.
      final started = await subject.startNew();

      final read = await subject.fetchSingle(started.id);

      expect(read.startedAt.isAtSameMomentAs(started.startedAt), isTrue);
      expect(read.startedAt.toUtc(), started.startedAt);
    },
  );

  test('renaming changes the name and nothing else', () async {
    final started = await subject.startNew(
      activityType: ActivityTypeEntity.run,
    );

    await subject.updateName(started.id, 'Morning loop');

    final stored = await subject.fetchSingle(started.id);
    expect(stored.name, 'Morning loop');
    expect(stored.activityType, ActivityTypeEntity.run);
    expect(stored.startedAt.isAtSameMomentAs(started.startedAt), isTrue);
  });

  test('deleting removes the activity', () async {
    final started = await subject.startNew();
    await subject.score(started.id, [fix(clock.nowUtc())]);

    await subject.delete(started.id);

    expect(await subject.fetchSummaries(), isEmpty);
  });

  test('summaries are newest first and paginate', () async {
    final ids = <String>[];
    for (var i = 0; i < 3; i++) {
      ids.add((await subject.startNew()).id);
      await subject.cease(ids.last);
      clock.advance(const Duration(hours: 1));
    }

    final page = await subject.fetchSummaries(limit: 2);
    expect(page.map((s) => s.id), [ids[2], ids[1]]);
    expect(
      (await subject.fetchSummaries(limit: 2, offset: 2)).map((s) => s.id),
      [ids[0]],
    );
  });

  test('a recording checkpoint round-trips', () async {
    final started = await subject.startNew();
    final pausedAt = clock.nowUtc().add(const Duration(minutes: 5));

    await subject.saveRecordingCheckpoint(
      started.id,
      pausedAt: pausedAt,
      completedPauses: const Duration(seconds: 90),
    );

    final checkpoint = await subject.fetchRecordingCheckpoint(started.id);
    expect(checkpoint?.pausedAt, pausedAt);
    expect(checkpoint?.completedPauses, const Duration(seconds: 90));
  });

  test('live aggregates are written without touching the points', () async {
    final started = await subject.startNew();
    await subject.score(started.id, [fix(clock.nowUtc())]);

    await subject.updateLiveAggregates(
      started.id,
      distanceMeters: 1234,
      activeDuration: const Duration(minutes: 7),
    );

    final summary = (await subject.fetchSummaries()).single;
    expect(summary.activeDistanceMeters, 1234);
    expect((await subject.fetchSingle(started.id)).points, hasLength(1));
  });
}
