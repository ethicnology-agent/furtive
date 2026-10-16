import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/superseded_areas.dart';
import 'package:map_view/map_view.dart';

OfflineArea area(int id, String key, {String name = ''}) =>
    OfflineArea(id: id, name: name, key: key);

void main() {
  group('supersededAreaIds', () {
    const key = '48.000,-71.500@25/10.0-15.0';

    test('a finished download that superseded nothing deletes nothing', () {
      expect(supersededAreaIds([area(1, key)], key), isEmpty);
    });

    test('nothing is deleted when the store is empty', () {
      expect(supersededAreaIds(const [], key), isEmpty);
    });

    test(
      'the leftover of an interrupted download is dropped, the newest kept',
      () {
        // The shape the renderer actually leaves behind: asking again does
        // not resume, it creates a second region beside the first.
        final ids = supersededAreaIds([area(7, key), area(9, key)], key);
        expect(ids, [7]);
      },
    );

    test('order in the list does not decide which region survives', () {
      // list() gives no ordering guarantee, and picking the last element
      // rather than the highest id would delete the finished download.
      expect(supersededAreaIds([area(9, key), area(7, key)], key), [7]);
    });

    test('several leftovers are all dropped, keeping only the newest', () {
      final ids = supersededAreaIds([
        area(3, key),
        area(11, key),
        area(5, key),
      ], key);
      expect(ids, [3, 5]);
    });

    test('an area asked for somewhere else is never touched', () {
      const elsewhere = '45.500,-73.600@25/10.0-15.0';
      expect(
        supersededAreaIds([
          area(1, elsewhere),
          area(2, key),
          area(3, key),
        ], key),
        [2],
      );
    });

    test(
      'a region kept by an older build carries no key and is left alone',
      () {
        // Those regions predate the identity metadata. Treating an absent key
        // as a match would delete the user's existing offline maps the first
        // time they downloaded anything.
        expect(supersededAreaIds([area(1, ''), area(2, '')], ''), isEmpty);
        expect(supersededAreaIds([area(1, ''), area(2, key)], key), isEmpty);
      },
    );
  });
}
