import 'dart:math' as math;

import 'package:geo/geo.dart';

/// How many resources a download of [bounds] between the two zooms will fetch.
///
/// The tiles are exact, not an estimate. The renderer walks the standard
/// slippy-map grid, so that part is geometry — and the arithmetic was checked
/// against seven measured downloads on an Android 12 device, from 918 tiles
/// to 180,685: every one of them fetched exactly this many plus 395.
///
/// Those 395 are the style, its sprites and its glyph ranges. They do not
/// vary with the area, which is what makes them a constant here — but they
/// were measured against one style in one language, and the glyph ranges a
/// style needs depend on the alphabet it labels in. Expect the constant to
/// be wrong for a language that is not written in Latin script. It is a
/// rounding error against any real download and the error does not grow with
/// the area, so it is carried rather than modelled.
///
/// Worth having because bytes cannot be predicted the same way: the same
/// number of tiles measured 1.1 KB each over open country and 11 KB each over
/// Paris. The count is honest; a size would not be.
int tilesForDownload({
  required GeoBounds bounds,
  required double minZoom,
  required double maxZoom,
}) {
  if (bounds.isEmpty) return 0;
  var total = 0;
  for (var z = minZoom.floor(); z <= maxZoom.floor(); z++) {
    total += _tilesAtZoom(bounds, z);
  }
  return total + _fixedResources;
}

/// Style, sprites and glyphs: measured against a Latin-script style, and
/// independent of the area asked for. See the note above.
const _fixedResources = 395;

int _tilesAtZoom(GeoBounds bounds, int z) {
  final scale = 1 << z;
  final x1 = _lonToTile(bounds.west, scale);
  final x2 = _lonToTile(bounds.east, scale);
  // y grows southward, so the northern edge gives the smaller index.
  final y1 = _latToTile(bounds.north, scale);
  final y2 = _latToTile(bounds.south, scale);
  return (x2 - x1 + 1) * (y2 - y1 + 1);
}

int _lonToTile(double lon, int scale) =>
    ((lon + 180.0) / 360.0 * scale).floor().clamp(0, scale - 1);

/// Web Mercator cannot represent the poles, so latitudes are clamped to the
/// usual limit before projection rather than returning an index off the grid.
const _mercatorLimit = 85.05112878;

int _latToTile(double lat, int scale) {
  final clamped = lat.clamp(-_mercatorLimit, _mercatorLimit);
  final radians = clamped * math.pi / 180.0;
  final y = (1 - _asinh(math.tan(radians)) / math.pi) / 2 * scale;
  return y.floor().clamp(0, scale - 1);
}

double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));
