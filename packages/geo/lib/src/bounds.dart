import 'dart:math' as math;

import 'position.dart';

/// A rectangle on the sphere, in degrees.
///
/// Lives here rather than in the renderer's module because it is geography,
/// not rendering: the area a user wants kept offline is the same rectangle
/// whatever draws it, and a port that spoke the renderer's own bounds type
/// would leak that renderer into every caller.
class GeoBounds {
  const GeoBounds({
    required this.west,
    required this.east,
    required this.south,
    required this.north,
  });

  final double west;
  final double east;
  final double south;
  final double north;

  /// True when the rectangle has no area, which every consumer should refuse
  /// rather than hand to a tile downloader that would enumerate nothing.
  bool get isEmpty => west >= east || south >= north;
}

/// Metres per degree of latitude. Constant enough: the meridian varies by
/// about 0.5% between equator and pole, which is far below the precision a
/// download radius needs.
const _metresPerDegreeLatitude = 111320.0;

/// The rectangle enclosing a circle of [radiusMetres] around [centre].
///
/// A square bounding box rather than the circle itself, because tile
/// downloaders work in rectangles — the corners pull in slightly more area
/// than asked for, which costs tiles and never costs coverage.
///
/// Longitude degrees shrink with latitude, so the east-west half-width is
/// divided by cos(latitude). Near the poles that divisor approaches zero and
/// the box would span the globe; it is clamped so a caller gets a usable
/// rectangle instead of the planet. Returns null for a non-finite centre or a
/// non-positive radius rather than a degenerate box.
GeoBounds? boundsAround(PositionEntity centre, double radiusMetres) {
  if (!radiusMetres.isFinite || radiusMetres <= 0) return null;
  if (!centre.latitude.isFinite || !centre.longitude.isFinite) return null;

  final latitudeDelta = radiusMetres / _metresPerDegreeLatitude;
  final cosine = math.cos(centre.latitude * math.pi / 180);
  // 0.01 ≈ latitude 89.4°. Past that the box is meaningless anyway; clamping
  // keeps it finite rather than letting it wrap the whole parallel.
  final scale = cosine.abs() < 0.01 ? 0.01 : cosine.abs();
  final longitudeDelta = latitudeDelta / scale;

  return GeoBounds(
    west: centre.longitude - longitudeDelta,
    east: centre.longitude + longitudeDelta,
    south: (centre.latitude - latitudeDelta).clamp(-90.0, 90.0),
    north: (centre.latitude + latitudeDelta).clamp(-90.0, 90.0),
  );
}
