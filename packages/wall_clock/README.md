# wall_clock

An injectable source of "now".

## When to use it

Everywhere the wall clock is read. Take a `Clock` rather than calling
`DateTime.now()`, and default the parameter to `const SystemClock()` so
production call sites stay unchanged.

It exists because several of the application's windows are otherwise
unreachable from a test: the 12 hours after which an unfinished recording is
treated as abandoned rather than resumable, the 20 seconds of silence after
which the position stream is assumed suspended, the update-check TTL, and
all of the elapsed and paused bookkeeping during a recording.

## Example

```dart
class Thing {
  Thing({this.clock = const SystemClock()});
  final Clock clock;
}

final clock = FixedClock(DateTime.utc(2026, 1, 1));
clock.advance(const Duration(hours: 13)); // trip the stale-activity window
```

## Owned and borrowed

Owned: the `Clock` contract and its two implementations. Nothing is
borrowed; there is no resource and no lifecycle.

## Guarantees

Every implementation returns **UTC**. That is a contract, not a convention:
every timestamp the application persists, compares or serialises is UTC, and
a local-flagged DateTime mixed into that is the classic source of
off-by-hours duration bugs. `FixedClock` converts whatever it is handed, so
a test that seeds local time cannot smuggle one in.

A `FixedClock` moves only when told. `advance` accepts a negative duration,
which is how a clock going backwards — an NTP correction, a user changing
the device time — gets exercised.

## Verification

`test/clock_test.dart` covers that the system clock reports UTC, that a
fixed clock is stable between reads, that advancing accumulates and accepts
a negative delta, that `set` jumps absolutely, and that local time handed in
comes back as UTC.
