import 'dart:math' as math;

/// WGS84 equatorial radius, in metres.
const double earthRadiusMeters = 6378137.0;

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Great-circle distance between two WGS84 coordinates, in metres.
///
/// Transcribed from `GeolocatorPlatform.distanceBetween`
/// (geolocator_platform_interface 4.4.0), expression for expression and in
/// the same order, so the figure is bit-identical to the one every recording
/// already in a user's database was measured with.
///
/// The order is not cosmetic: merely swapping the two `cos` factors below
/// breaks bit equality on three of the four comparisons in
/// `test/distance_parity_test.dart`, which is why this is a transcription
/// and not a reimplementation. `pow(x, 2)` and `x * x` do agree here — the
/// `pow` form is kept because the source uses it, not because it was
/// measured to matter.
///
/// It lives here rather than being borrowed from the plugin because it is
/// arithmetic, not a platform capability: reaching for geolocator to measure
/// a distance would put a platform plugin underneath every module that needs
/// one.
double distanceBetween(
  double startLatitude,
  double startLongitude,
  double endLatitude,
  double endLongitude,
) {
  final dLat = _toRadians(endLatitude - startLatitude);
  final dLon = _toRadians(endLongitude - startLongitude);

  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.pow(math.sin(dLon / 2), 2) *
          math.cos(_toRadians(startLatitude)) *
          math.cos(_toRadians(endLatitude));
  final c = 2 * math.asin(math.sqrt(a));

  return earthRadiusMeters * c;
}
