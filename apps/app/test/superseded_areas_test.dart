import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/superseded_areas.dart';
import 'package:map_view/map_view.dart';

OfflineArea area(int id, String key, {String name = ''}) =>
    OfflineArea(id: id, name: name, key: key);

void main() {
  group('supersededAreaIds', () {
    const key = '48.000,-71.500@25/10.0-15.0';

    test('a finished download that superseded nothing deletes nothing', () {
      expect(supersededAreaIds([area(1, key)], key, keepId: 1), isEmpty);
    });

    test('nothing is deleted when the store is empty', () {
      expect(supersededAreaIds(const [], key, keepId: 1), isEmpty);
    });

    test('the leftover of an interrupted download is dropped, the finished one '
        'kept', () {
      // The shape the renderer actually leaves behind: asking again does
      // not resume, it creates a second region beside the first.
      expect(supersededAreaIds([area(7, key), area(9, key)], key, keepId: 9), [
        7,
      ]);
    });

    test('the region that just finished is kept even if its id is lower', () {
      // Ids are not ordered by time on every platform — the iOS plugin
      // derives them from a timestamp hash. Keeping the highest would delete
      // the download that just succeeded and leave the partial one behind,
      // recorded as complete.
      expect(supersededAreaIds([area(7, key), area(9, key)], key, keepId: 7), [
        9,
      ]);
    });

    test('order in the list does not decide which region survives', () {
      expect(supersededAreaIds([area(9, key), area(7, key)], key, keepId: 9), [
        7,
      ]);
    });

    test('several leftovers are all dropped, keeping the finished one', () {
      expect(
        supersededAreaIds(
          [area(3, key), area(11, key), area(5, key)],
          key,
          keepId: 11,
        ),
        [3, 5],
      );
    });

    test('an area asked for somewhere else is never touched', () {
      const elsewhere = '45.500,-73.600@25/10.0-15.0';
      expect(
        supersededAreaIds(
          [area(1, elsewhere), area(2, key), area(3, key)],
          key,
          keepId: 3,
        ),
        [2],
      );
    });

    test('nothing is deleted when the finished region is unknown', () {
      // Without an id to keep, every match would be deleted — including the
      // download that just succeeded.
      expect(
        supersededAreaIds([area(1, key), area(2, key)], key, keepId: null),
        isEmpty,
      );
    });

    test('nothing is deleted when the id to keep is not among them', () {
      // The region went away between finishing and sweeping. Deleting the
      // rest would leave the area with nothing at all.
      expect(
        supersededAreaIds([area(1, key), area(2, key)], key, keepId: 99),
        isEmpty,
      );
    });

    test(
      'a region kept by an older build carries no key and is left alone',
      () {
        expect(
          supersededAreaIds([area(1, ''), area(2, '')], '', keepId: 1),
          isEmpty,
        );
        expect(
          supersededAreaIds([area(1, ''), area(2, key)], key, keepId: 2),
          isEmpty,
        );
      },
    );
  });
}
