import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/offline_ledger.dart';

void main() {
  late Directory dir;
  late File file;
  late OfflineLedger ledger;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('ledger');
    file = File('${dir.path}/offline_areas.json');
    ledger = OfflineLedger(file);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('a ledger that was never written reads as empty', () async {
    expect(await ledger.read(), isEmpty);
  });

  test('what a download cost survives being written and read back', () async {
    await ledger.record(
      'a',
      const OfflineAreaCost(tiles: 1313, bytes: 7026194),
    );
    final back = await ledger.read();
    expect(back['a']?.tiles, 1313);
    expect(back['a']?.bytes, 7026194);
  });

  test(
    'finishing an interrupted download replaces its row, not adds one',
    () async {
      // The retry carries the same identity, and counting both would report
      // twice the storage the device actually holds.
      await ledger.record('a', const OfflineAreaCost(tiles: 100, bytes: 1000));
      await ledger.record('a', const OfflineAreaCost(tiles: 500, bytes: 5000));
      final back = await ledger.read();
      expect(back, hasLength(1));
      expect(back['a']?.bytes, 5000);
    },
  );

  test('rows for areas no longer on the device are dropped', () async {
    await ledger.record('a', const OfflineAreaCost(tiles: 1, bytes: 1));
    await ledger.record('b', const OfflineAreaCost(tiles: 2, bytes: 2));
    await ledger.retainOnly({'b'});
    expect((await ledger.read()).keys, ['b']);
  });

  test('an empty key is not recorded', () async {
    // Regions kept by an earlier build carry no identity; giving them all the
    // same empty row would merge their costs into one.
    await ledger.record('', const OfflineAreaCost(tiles: 9, bytes: 9));
    expect(await ledger.read(), isEmpty);
  });

  test('a download killed part way is still accounted for', () async {
    // What happened in the wild: France was interrupted at about 5,000
    // tiles, and because the cost was only written at completion the area
    // came back listed with nothing beside it while 296 MB sat on disk.
    await ledger.record(
      'fr',
      const OfflineAreaCost(tiles: 5000, bytes: 296_700_000, complete: false),
    );
    final back = await ledger.read();
    expect(back['fr']?.tiles, 5000);
    expect(back['fr']?.complete, isFalse);
  });

  test('finishing replaces the partial row and marks it complete', () async {
    await ledger.record(
      'fr',
      const OfflineAreaCost(tiles: 5000, bytes: 1000, complete: false),
    );
    await ledger.record(
      'fr',
      const OfflineAreaCost(tiles: 2221390, bytes: 9000),
    );
    final back = await ledger.read();
    expect(back, hasLength(1));
    expect(back['fr']?.complete, isTrue);
    expect(back['fr']?.tiles, 2221390);
  });

  test(
    'a row written before completeness was recorded reads as complete',
    () async {
      // Those rows only ever existed for finished downloads, so defaulting
      // them to unfinished would relabel every area the user already kept.
      await file.writeAsString(
        jsonEncode({
          'a': {'tiles': 1, 'bytes': 2},
        }),
      );
      final back = await ledger.read();
      expect(back['a']?.complete, isTrue);
    },
  );

  test('a half-written ledger cannot replace a good one', () async {
    // The write happens every few seconds during a download, so being
    // killed mid-write is the ordinary case rather than the rare one.
    // Writing in place truncated the file first, and what came back read as
    // empty — losing every area's accounting, not just the one being
    // written.
    await ledger.record('a', const OfflineAreaCost(tiles: 1, bytes: 1));
    await ledger.record('b', const OfflineAreaCost(tiles: 2, bytes: 2));
    expect(await ledger.read(), hasLength(2));
    // Nothing but the ledger itself is left behind by a successful write.
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('overlapping writes do not lose the later one', () async {
    // Progress, completion and pruning all read-modify-write and can
    // overlap. Interleaved, a stale snapshot could land on top of a newer.
    final writes = [
      ledger.record('a', const OfflineAreaCost(tiles: 1, bytes: 1)),
      ledger.record('b', const OfflineAreaCost(tiles: 2, bytes: 2)),
      ledger.record('c', const OfflineAreaCost(tiles: 3, bytes: 3)),
    ];
    await Future.wait(writes);
    expect((await ledger.read()).keys, containsAll(['a', 'b', 'c']));
  });

  test(
    'a prune racing a record keeps the record it did not know about',
    () async {
      await ledger.record('old', const OfflineAreaCost(tiles: 1, bytes: 1));
      final both = [
        ledger.retainOnly({'old'}),
        ledger.record('new', const OfflineAreaCost(tiles: 2, bytes: 2)),
      ];
      await Future.wait(both);
      // Serialised, the prune runs first and the record lands after it.
      expect((await ledger.read()).containsKey('new'), isTrue);
    },
  );

  group('how far an unfinished area got', () {
    test('a fraction needs a total to measure against', () {
      const unknown = OfflineAreaCost(tiles: 100, bytes: 1, complete: false);
      expect(unknown.fraction, isNull);
    });

    test('a partial area reports its share of the whole', () {
      const half = OfflineAreaCost(
        tiles: 50,
        bytes: 1,
        expected: 100,
        complete: false,
      );
      expect(half.fraction, 0.5);
    });

    test('more tiles than expected still reads as finished, not over', () {
      // The renderer counts resources as well as tiles, and the total it
      // reports early is a lower bound. A bar past 100% would look broken.
      const over = OfflineAreaCost(tiles: 120, bytes: 1, expected: 100);
      expect(over.fraction, 1.0);
    });

    test('the total survives being written and read back', () async {
      await ledger.record(
        'a',
        const OfflineAreaCost(
          tiles: 50,
          bytes: 1,
          expected: 200,
          complete: false,
        ),
      );
      expect((await ledger.read())['a']?.fraction, 0.25);
    });

    test('a row from before the total was recorded has no fraction', () async {
      await file.writeAsString(
        jsonEncode({
          'a': {'tiles': 1, 'bytes': 2, 'complete': false},
        }),
      );
      expect((await ledger.read())['a']?.fraction, isNull);
    });
  });

  test('a corrupt file reads as empty rather than throwing', () async {
    await file.writeAsString('{not json');
    expect(await ledger.read(), isEmpty);
  });

  test('a malformed row is skipped, and does not read as zero', () async {
    // Reading a bad row as 0 bytes would silently under-report the total,
    // which is worse than omitting it: the number would look authoritative.
    await file.writeAsString(
      jsonEncode({
        'good': {'tiles': 10, 'bytes': 100},
        'missing': {'tiles': 10},
        'wrongType': {'tiles': 'x', 'bytes': 1},
        'negative': {'tiles': -1, 'bytes': 1},
        'notAMap': 5,
      }),
    );
    final back = await ledger.read();
    expect(back.keys, ['good']);
  });
}
