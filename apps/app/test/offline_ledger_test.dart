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
