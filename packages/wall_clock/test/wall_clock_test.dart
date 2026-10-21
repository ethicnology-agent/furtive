import 'package:wall_clock/wall_clock.dart';
import 'package:test/test.dart';

void main() {
  test('the system clock reports UTC', () {
    // Not a style preference: every timestamp the application persists,
    // compares or serialises is UTC, and a local-flagged DateTime mixed into
    // that is the classic source of off-by-hours duration bugs.
    expect(const SystemClock().nowUtc().isUtc, isTrue);
  });

  test('a fixed clock does not move on its own', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));

    expect(clock.nowUtc(), clock.nowUtc());
    expect(clock.nowUtc(), DateTime.utc(2026, 1, 1));
  });

  test('advancing moves time forward by exactly the delta', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));

    clock.advance(const Duration(hours: 13));

    expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 13));
  });

  test('advancing twice accumulates', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));

    clock.advance(const Duration(hours: 12));
    clock.advance(const Duration(hours: 1));

    expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 13));
  });

  test('a negative delta moves time back', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 1, 12));

    clock.advance(const Duration(hours: -2));

    expect(clock.nowUtc(), DateTime.utc(2026, 1, 1, 10));
  });

  test('set jumps to an absolute instant', () {
    final clock = FixedClock(DateTime.utc(2026, 1, 1));

    clock.set(DateTime.utc(2027, 6, 15, 8, 30));

    expect(clock.nowUtc(), DateTime.utc(2027, 6, 15, 8, 30));
  });

  test('a local time handed to a fixed clock comes back as UTC', () {
    // A test that seeds local time must not thereby make the subject compare
    // a local instant against the UTC ones it stores.
    final local = DateTime(2026, 1, 1, 12);
    final clock = FixedClock(local);

    expect(clock.nowUtc().isUtc, isTrue);
    expect(clock.nowUtc(), local.toUtc());

    clock.set(DateTime(2026, 3, 4, 9));
    expect(clock.nowUtc().isUtc, isTrue);
  });
}
