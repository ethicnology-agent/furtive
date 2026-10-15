import 'package:geo/geo.dart';
import 'package:test/test.dart';

/// Coverage for the rectangle an offline download is asked for.
///
/// The interesting cases are the ones where a naive implementation silently
/// produces something unusable: the poles, where longitude degrees collapse,
/// and the degenerate inputs a UI can hand over before a fix has arrived.
void main() {
  PositionEntity at(double latitude, double longitude) =>
      PositionEntity(latitude: latitude, longitude: longitude, elevation: 0);

  group('boundsAround', () {
    test('a radius at the equator is square in degrees', () {
      final bounds = boundsAround(at(0, 0), 111320)!;
      expect(bounds.north, closeTo(1, 0.01));
      expect(bounds.south, closeTo(-1, 0.01));
      // At the equator cos(0) = 1, so longitude and latitude spans match.
      expect(bounds.east, closeTo(1, 0.01));
      expect(bounds.west, closeTo(-1, 0.01));
    });

    test('longitude widens with latitude, because its degrees shrink', () {
      final equator = boundsAround(at(0, 0), 10000)!;
      final north = boundsAround(at(60, 0), 10000)!;
      expect(north.east - north.west, greaterThan(equator.east - equator.west));
      // Latitude is unaffected: a metre north is a metre north anywhere.
      expect(
        north.north - north.south,
        closeTo(equator.north - equator.south, 1e-9),
      );
    });

    test('a pole yields a finite box rather than the whole parallel', () {
      final bounds = boundsAround(at(89.999, 0), 10000)!;
      expect(bounds.east - bounds.west, lessThan(360));
      expect(bounds.north, lessThanOrEqualTo(90));
      expect(bounds.isEmpty, isFalse);
    });

    test('degenerate input yields null, not an empty rectangle', () {
      expect(boundsAround(at(0, 0), 0), isNull);
      expect(boundsAround(at(0, 0), -1), isNull);
      expect(boundsAround(at(0, 0), double.nan), isNull);
      expect(boundsAround(at(double.nan, 0), 100), isNull);
    });

    test('a well-formed box is not empty, and a collapsed one is', () {
      expect(boundsAround(at(45, 5), 500)!.isEmpty, isFalse);
      const collapsed = GeoBounds(west: 1, east: 1, south: 0, north: 1);
      expect(collapsed.isEmpty, isTrue);
    });
  });
}
