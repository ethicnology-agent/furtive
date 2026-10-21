# location

The device's position stream, filtered for the activity being recorded.

## When to use it

Whenever something needs to know where the device is, or whether it still
knows. `LocationRepository` is the contract: it opens the stream, filters
it, and reports the permission and battery state that decide whether a
recording can survive the screen going off.

## Example

```dart
final location = LocationRepository();
final fixes = await location.positionStream(
  profile: activityType.movementProfile,
  detail: RecordingDetailEntity.balanced,
);
```

## Owned and borrowed

Owned: the platform position stream and its configuration, its lifetime —
opening, reopening, and noticing it has gone silent — the quality filter,
the gap detector, and the compass channel. Borrowed: the device's
permissions, which belong to the user and can be revoked while a recording
runs.

`package:location/testing.dart` exposes the platform datasource and a
hand-written fake repository whose fixes a test drives directly, so a test
can stand in for a GPS receiver. Production code must not import it.

## Guarantees

A receiver reports more than it knows, and the filtering is where that is
dealt with rather than in whatever reads the stream.

`plausibleSpeedMps` is not a rejection ceiling. Exceeding it makes a fix
*suspicious*, and the filter re-anchors after a few consecutive suspicions,
so a genuinely fast vehicle can never be filtered into silence — the
previous single ceiling rejected every fix of a car above 126 km/h,
permanently, because a rejection did not move the comparison anchor.

A missing accuracy estimate means the provider did not report quality, not
that it reported poor quality: such a fix stays usable.

`SignalGapDetector` measures the cadence rather than the speed, calibrated
to the median of recent intervals and clamped at both ends. A gap is only
observable when the fix that *ends* it arrives, so it is reported
retroactively and never predicted.

`PositionStreamController` owns when the stream is open, not just what it
emits. A platform stream can stop delivering without closing — the process
is backgrounded, the OS suspends it, location services are switched off and
back on — so silence past a threshold is treated as death and the stream is
reopened. A closed stream is never read as "the user stopped": the
foreground service holds a wake lock and an ongoing notification, so a close
means the service died rather than that anyone asked it to.

A heading is reported only while the device is actually moving; see
`PositionEntity.trustedHeading` in `geo`, which this module's consumers read
rather than the raw bearing.

## Verification

`test/gps_quality_filter_test.dart` covers accepting, rejecting and
re-anchoring. `test/signal_gap_detector_test.dart` covers the threshold and
its clamps. `test/location_repository_test.dart` covers the stream, the
heading, and the permission and battery pass-through.
`test/location_gps_settings_test.dart` covers what reaches the platform per
profile. `test/compass_facade_test.dart` covers the smoothing and the
fallback when no heading is available.
`test/position_stream_controller_test.dart` covers opening, the staleness
threshold, reopening, and recovery when location services return.
