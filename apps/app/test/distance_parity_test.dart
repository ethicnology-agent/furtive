import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:geo/geo.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Holds geo's transcribed distance beside the plugin's original.
///
/// Every distance already stored in a user's database was measured with
/// `Geolocator.distanceBetween`. A transcription that is merely *close* would
/// silently rewrite the statistics of recordings made before it, so the bar
/// here is bit equality, not a tolerance. This test is the only reason the
/// application still imports geolocator for arithmetic; when the plugin is
/// upgraded and this test fails, the transcription has to be re-checked
/// against the new source rather than the expectation relaxed.
void main() {
  double reference(double aLat, double aLon, double bLat, double bLon) =>
      Geolocator.distanceBetween(aLat, aLon, bLat, bLon);

  void expectIdentical(double aLat, double aLon, double bLat, double bLon) {
    final mine = geo.distanceBetween(aLat, aLon, bLat, bLon);
    final theirs = reference(aLat, aLon, bLat, bLon);
    expect(mine, theirs, reason: 'distanceBetween($aLat, $aLon, $bLat, $bLon)');
  }

  test('matches the plugin on the fixes a recording is made of', () {
    // Consecutive fixes a few metres apart, which is the case that actually
    // accumulates: a recording sums thousands of these.
    var latitude = 48.8566;
    var longitude = 2.3522;
    for (var step = 0; step < 500; step++) {
      final next = latitude + 0.00004, nextLon = longitude + 0.00003;
      expectIdentical(latitude, longitude, next, nextLon);
      latitude = next;
      longitude = nextLon;
    }
  });

  test('matches the plugin across the globe, poles and meridians', () {
    const points = [
      (0.0, 0.0),
      (90.0, 0.0),
      (-90.0, 0.0),
      (0.0, 180.0),
      (0.0, -180.0),
      (48.8566, 2.3522),
      (-33.8688, 151.2093),
      (64.1466, -21.9426),
      (1.3521, 103.8198),
      (-54.8019, -68.3030),
    ];
    for (final (aLat, aLon) in points) {
      for (final (bLat, bLon) in points) {
        expectIdentical(aLat, aLon, bLat, bLon);
      }
    }
  });

  test('matches the plugin on degenerate and antipodal pairs', () {
    expectIdentical(48.8566, 2.3522, 48.8566, 2.3522);
    expectIdentical(0, 0, 0, 0.0000001);
    expectIdentical(51.4779, 0, -51.4779, 180);
  });

  test('matches the plugin on pseudo-random coordinates', () {
    final random = math.Random(20261005);
    for (var i = 0; i < 2000; i++) {
      expectIdentical(
        random.nextDouble() * 180 - 90,
        random.nextDouble() * 360 - 180,
        random.nextDouble() * 180 - 90,
        random.nextDouble() * 360 - 180,
      );
    }
  });

  test('agrees with the radius the accuracy circle is drawn with', () {
    // geo_circle.dart builds its ring on the same WGS84 radius so a circle
    // drawn there and a distance measured here cannot disagree.
    expect(geo.earthRadiusMeters, 6378137.0);
  });
}
