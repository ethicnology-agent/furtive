import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/kept_areas.dart';
import 'package:map_view/map_view.dart';

OfflineArea region(int id, String key, {String name = 'France'}) =>
    OfflineArea(id: id, name: name, key: key);

void main() {
  group('keptAreas', () {
    const france = 'country:FR/10.0-15.0@1a2b';

    test('one region is one area', () {
      final areas = keptAreas([region(1, france)]);
      expect(areas, hasLength(1));
      expect(areas.single.regionIds, [1]);
    });

    test('an area asked for twice is listed once', () {
      // There is no resume: every retry of an interrupted download creates
      // another region under the same identity, and the sweep that removes
      // them only runs when a download finishes. A country never finishes
      // on the current renderer plugin, so listing regions showed France
      // twice, each row repeating the one cost recorded for it.
      final areas = keptAreas([region(1, france), region(2, france)]);
      expect(areas, hasLength(1));
      expect(areas.single.regionIds, [1, 2]);
      expect(areas.single.name, 'France');
    });

    test('every region of an area is offered for deletion together', () {
      // Removing one would leave the row in place holding the others.
      final areas = keptAreas([
        region(3, france),
        region(1, france),
        region(2, france),
      ]);
      expect(areas.single.regionIds, [1, 2, 3]);
    });

    test('different areas stay apart', () {
      const spain = 'country:ES/10.0-15.0@1a2b';
      final areas = keptAreas([
        region(1, france),
        region(2, spain, name: 'Spain'),
      ]);
      expect(areas, hasLength(2));
      expect({for (final a in areas) a.name}, {'France', 'Spain'});
    });

    test('the same place in two styles is two areas', () {
      // The style is part of the identity, so a theme change is a different
      // request rather than a retry of the same one.
      const dark = 'country:FR/10.0-15.0@9z8y';
      expect(keptAreas([region(1, france), region(2, dark)]), hasLength(2));
    });

    test('regions from a build that wrote no identity stay separate', () {
      // They cannot be told apart, so merging them would claim a grouping
      // that is not known to exist.
      final areas = keptAreas([
        region(1, '', name: ''),
        region(2, '', name: ''),
      ]);
      expect(areas, hasLength(2));
    });

    test('nothing kept is no areas', () {
      expect(keptAreas(const []), isEmpty);
    });
  });
}
