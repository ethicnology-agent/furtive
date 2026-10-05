# geo

One GPS fix, with the uncertainties the platform reported alongside it.

## When to use it

Whenever a module needs to speak about a place. It sits below every
capability because activities, location and the basemap all need this type
and none of them may depend on another; putting it in any one of them would
make the dependency graph cyclic.

Keep it to what a receiver reports. Anything derived — a distance, a filter,
a track — belongs to the module that derives it.

## Example

```dart
final arrow = position.trustedHeading;
if (arrow != null) paintChevron(arrow);
```

## Owned and borrowed

Owned: `PositionEntity` and the reading of its reported values. Nothing else;
the type holds no resource and has no lifecycle.

## Guarantees

Every uncertainty field is nullable and null means **unknown**, never
"perfect". A fix synthesised by the application — a map search centre, an
interpolated milestone — carries none of them, and neither does a recording
made before a field existed.

`trustedHeading` is the only place that interprets rather than reports. It
returns a course only when one can be believed, guarding the two ways the
platform lies: a bearing emitted while standing still, and Android filling
the field with 0.0 when no bearing exists at all, which is indistinguishable
from a genuine due-north course. Read it rather than `heading`.

`kMinSpeedForHeadingMps` is a starting value to validate against real
recordings, not a measured constant.

## Verification

`test/position_test.dart` covers the heading contract: the threshold in both
directions and at its exact boundary, an unknown speed, a missing heading,
and the non-finite and out-of-range values the platform can produce.

`test/distance_test.dart` covers the distance against the sphere it is
defined on: identity, a quarter of the equator, pole to pole by either
meridian, antipodes, the pole where longitude costs nothing, symmetry, the
published Paris-London figure, a metre-scale step, and the antimeridian.
The application holds the same function against geolocator's original in
`test/distance_parity_test.dart`; that one is the bit-equality check and
needs the plugin, so it cannot live here.
