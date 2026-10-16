import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geo/geo.dart';
import 'package:map_view/map_view.dart';

/// The box `boundsAround` produces, rebuilt here so a case can be written
/// with the centre and radius that were actually downloaded.
GeoBounds around(double lat, double lon, double radiusKm) {
  const metresPerDegreeLatitude = 111320.0;
  final dLat = radiusKm * 1000 / metresPerDegreeLatitude;
  final cosine = math.cos(lat * math.pi / 180).abs();
  final dLon = dLat / (cosine < 0.01 ? 0.01 : cosine);
  return GeoBounds(
    west: lon - dLon,
    south: lat - dLat,
    east: lon + dLon,
    north: lat + dLat,
  );
}

int count(GeoBounds b) => tilesForDownload(bounds: b, minZoom: 10, maxZoom: 15);

void main() {
  group('tilesForDownload against downloads measured on an Android device', () {
    // Samsung SM-G970U1, z10-15. These are the numbers the renderer
    // reported, not derived from the formula under test.
    const rural = (lat: 48.0, lon: -71.5);
    const paris = (lat: 48.8566, lon: 2.3522);

    test('10 km over open country', () {
      expect(count(around(rural.lat, rural.lon, 10)), 1313);
    });

    test('25 km over open country', () {
      expect(count(around(rural.lat, rural.lon, 25)), 5585);
    });

    test('50 km over open country', () {
      expect(count(around(rural.lat, rural.lon, 50)), 20847);
    });

    test('100 km over open country', () {
      expect(count(around(rural.lat, rural.lon, 100)), 81050);
    });

    test('150 km over open country', () {
      expect(count(around(rural.lat, rural.lon, 150)), 181080);
    });

    test('10 km over Paris', () {
      // Same radius as the rural case and nearly the same count: tile count
      // follows geometry, and only the bytes differ with density.
      expect(count(around(paris.lat, paris.lon, 10)), 1331);
    });

    test('50 km over Paris', () {
      expect(count(around(paris.lat, paris.lon, 50)), 21611);
    });
  });

  group('tilesForDownload edges', () {
    test('an empty box needs nothing, not even the fixed resources', () {
      const empty = GeoBounds(west: 5, south: 5, east: 5, north: 5);
      expect(tilesForDownload(bounds: empty, minZoom: 10, maxZoom: 15), 0);
    });

    test('a single zoom level is counted once', () {
      final b = around(48, 2, 10);
      final one = tilesForDownload(bounds: b, minZoom: 12, maxZoom: 12);
      final two = tilesForDownload(bounds: b, minZoom: 12, maxZoom: 13);
      expect(one, lessThan(two));
    });

    test('a box reaching past the Mercator limit stays on the grid', () {
      // Latitudes beyond ±85.05 cannot be projected; clamping is what keeps
      // the row index inside the pyramid instead of running off it.
      const polar = GeoBounds(west: 10, south: 80, east: 20, north: 89.9);
      expect(
        tilesForDownload(bounds: polar, minZoom: 10, maxZoom: 10),
        greaterThan(0),
      );
    });

    test('the whole world at zoom 0 is one tile plus the fixed resources', () {
      const world = GeoBounds(west: -180, south: -85, east: 180, north: 85);
      expect(tilesForDownload(bounds: world, minZoom: 0, maxZoom: 0), 1 + 395);
    });
  });
}
