import 'dart:math' as math;

import 'package:geo/geo.dart';
import 'package:test/test.dart';

/// Covers distanceBetween against the sphere it is defined on.
///
/// The application also holds it against geolocator's original, which is the
/// bit-equality check and needs the plugin to exist. These are the properties
/// that hold regardless of whose implementation is running.
void main() {
  const paris = (48.8566, 2.3522);
  const london = (51.5074, -0.1278);

  double between((double, double) a, (double, double) b) =>
      distanceBetween(a.$1, a.$2, b.$1, b.$2);

  test('a point is no distance from itself', () {
    expect(between(paris, paris), 0);
  });

  test('a quarter of the equator is a quarter of the circumference', () {
    expect(
      distanceBetween(0, 0, 0, 90),
      closeTo(math.pi / 2 * earthRadiusMeters, 1e-6),
    );
  });

  test('pole to pole is half the circumference, by either meridian', () {
    final overZero = distanceBetween(90, 0, -90, 0);
    final overOneEighty = distanceBetween(90, 180, -90, 180);
    expect(overZero, closeTo(math.pi * earthRadiusMeters, 1e-6));
    expect(overOneEighty, closeTo(overZero, 1e-6));
  });

  test('antipodes are half the circumference apart', () {
    expect(
      distanceBetween(51.4779, 0, -51.4779, 180),
      closeTo(math.pi * earthRadiusMeters, 1e-3),
    );
  });

  test('longitude at the pole costs nothing', () {
    // Every meridian meets there, so moving along one is moving nowhere.
    expect(distanceBetween(90, 0, 90, 137), closeTo(0, 1e-6));
  });

  test('it is symmetric', () {
    expect(between(paris, london), between(london, paris));
  });

  test('it agrees with the published Paris-London great-circle distance', () {
    // ~343.5 km. The tolerance is 1 km: this is a sphere, and a geodesic on
    // the real ellipsoid differs by a few tenths of a percent.
    expect(between(paris, london), closeTo(343500, 1000));
  });

  test('a metre-scale step reads as metres, not as noise', () {
    // The case a recording actually accumulates thousands of.
    final step = distanceBetween(48.8566, 2.3522, 48.85664, 2.35223);
    expect(step, greaterThan(1));
    expect(step, lessThan(10));
  });

  test('crossing the antimeridian is short, not a lap of the planet', () {
    expect(distanceBetween(0, 179.99, 0, -179.99), lessThan(2500));
  });
}
