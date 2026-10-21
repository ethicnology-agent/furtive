import 'package:geo/geo.dart';
import 'package:test/test.dart';

PositionEntity fix({double? heading, double? speed}) => PositionEntity(
  latitude: 48.8566,
  longitude: 2.3522,
  elevation: 35,
  heading: heading,
  speed: speed,
);

void main() {
  group('trustedHeading', () {
    test('reports a course only while actually moving', () {
      expect(fix(heading: 90, speed: 3).trustedHeading, 90);
    });

    test('refuses a course from a stationary receiver', () {
      // A receiver that is not moving keeps emitting its last bearing, which
      // would peg an on-screen arrow to a direction nobody is travelling in.
      expect(fix(heading: 90, speed: 0).trustedHeading, isNull);
      expect(
        fix(heading: 90, speed: kMinSpeedForHeadingMps - 0.01).trustedHeading,
        isNull,
      );
    });

    test('accepts exactly the threshold speed', () {
      expect(
        fix(heading: 90, speed: kMinSpeedForHeadingMps).trustedHeading,
        90,
      );
    });

    test('refuses a course when speed is unknown', () {
      // Null is "unknown", never "fast enough".
      expect(fix(heading: 90).trustedHeading, isNull);
    });

    test('refuses a heading outside the compass range', () {
      expect(fix(heading: -1, speed: 3).trustedHeading, isNull);
      expect(fix(heading: 361, speed: 3).trustedHeading, isNull);
      expect(fix(heading: double.nan, speed: 3).trustedHeading, isNull);
      expect(fix(heading: double.infinity, speed: 3).trustedHeading, isNull);
    });

    test('keeps the range boundaries, which are real bearings', () {
      expect(fix(heading: 0, speed: 3).trustedHeading, 0);
      expect(fix(heading: 360, speed: 3).trustedHeading, 360);
    });

    test('refuses a missing heading', () {
      expect(fix(speed: 3).trustedHeading, isNull);
    });
  });
}
