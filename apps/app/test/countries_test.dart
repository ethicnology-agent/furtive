import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/countries.dart';
import 'package:map_view/map_view.dart';

Country byCode(String code) => countries.firstWhere((c) => c.code == code);

void main() {
  group('the country table', () {
    test('every box is a usable rectangle', () {
      // A degenerate box would be handed to the downloader and enumerate
      // nothing, or everything.
      for (final country in countries) {
        expect(country.bounds.isEmpty, isFalse, reason: country.name);
        expect(country.bounds.west, greaterThanOrEqualTo(-180));
        expect(country.bounds.east, lessThanOrEqualTo(180));
        expect(country.bounds.south, greaterThanOrEqualTo(-90));
        expect(country.bounds.north, lessThanOrEqualTo(90));
      }
    });

    test('no box spans more than half the planet', () {
      // Taking every piece of Fiji gives a box 360 degrees wide, because its
      // islands straddle the antimeridian. Keeping only the primary region is
      // what avoids asking for the whole world.
      for (final country in countries) {
        expect(
          country.bounds.east - country.bounds.west,
          lessThan(180),
          reason: country.name,
        );
      }
    });

    test('codes are unique, so an identity key cannot collide', () {
      final codes = countries.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('names are sorted, so the picker can show them as they come', () {
      final names = countries.map((c) => c.name).toList();
      expect(names, orderedEquals(List.of(names)..sort()));
    });

    test('France keeps Corsica and leaves French Guiana out', () {
      // The case the whole "primary region" rule exists for: one source
      // clips Corsica off, the other stretches France to South America.
      final fr = byCode('FR');
      expect(fr.bounds.south, lessThan(41.5)); // Corsica reaches 41.33
      expect(fr.bounds.west, greaterThan(-10)); // Guiana sits near -54
    });

    test('the United Kingdom keeps Northern Ireland', () {
      expect(byCode('GB').bounds.west, lessThan(-5.4));
    });

    test('Fiji is its main island rather than the antimeridian', () {
      final fj = byCode('FJ');
      expect(fj.bounds.east - fj.bounds.west, lessThan(10));
    });

    test('a country download is a real amount of work', () {
      // Guards the data against a silently empty or absurd box: France was
      // measured at 2.2 million tiles between zoom 10 and 15.
      final tiles = tilesForDownload(
        bounds: byCode('FR').bounds,
        minZoom: 10,
        maxZoom: 15,
      );
      expect(tiles, greaterThan(2000000));
      expect(tiles, lessThan(2500000));
    });
  });
}
