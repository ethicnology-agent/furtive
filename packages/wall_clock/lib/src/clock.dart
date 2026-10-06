abstract interface class Clock {
  /// Current wall-clock instant. Implementations MUST return UTC — every
  /// timestamp Furtive persists, compares or serialises is UTC, and mixing a
  /// local-flagged DateTime into that is the classic source of off-by-hours
  /// duration bugs.
  DateTime nowUtc();
}

/// Default [Clock]: the real system clock, in UTC.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// [Clock] whose time only moves when told to. For tests.
///
/// ```dart
/// final clock = FixedClock(DateTime.utc(2026, 1, 1));
/// clock.advance(const Duration(hours: 13)); // trip the stale-activity window
/// ```
final class FixedClock implements Clock {
  FixedClock(DateTime now) : _now = now.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Moves time forward by [delta].
  void advance(Duration delta) => _now = _now.add(delta);

  /// Jumps to an absolute instant.
  void set(DateTime now) => _now = now.toUtc();
}
