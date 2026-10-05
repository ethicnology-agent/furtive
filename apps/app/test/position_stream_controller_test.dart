import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/clock.dart';
import 'package:furtive/core/entities/position_entity.dart';
import 'package:furtive/features/map/position_stream_controller.dart';
import 'package:geolocator/geolocator.dart';

import 'support/fakes.dart';

class _PermissionLocation extends FakeLocationRepository {
  final permission = Completer<bool>();

  @override
  Future<bool> checkLocationPermission() => permission.future;
}

/// Coverage for the GPS stream lifecycle extracted from MapBloc.
///
/// Two hazards this guards, both of which produced real bugs before the
/// extraction: the check-then-act double-open race (which leaked a subscription
/// and double-wrote every fix to the database), and treating a silently
/// suspended stream as healthy because the subscription object still looks live.
void main() {
  late FakeLocationRepository location;
  late FixedClock clock;
  final start = DateTime.utc(2026, 7, 26, 10);

  setUp(() {
    clock = FixedClock(start);
    location = FakeLocationRepository();
  });

  tearDown(() => location.dispose());

  PositionStreamController build() =>
      PositionStreamController(location: location, clock: clock);

  test('ensureOpen opens the stream once', () async {
    final controller = build();
    await controller.ensureOpen();
    expect(controller.isOpen, isTrue);
    expect(location.positionStreamOpenCount, 1);
  });

  test(
    'concurrent ensureOpen calls share one open — the check-then-act race that '
    'used to leak a subscription and double-write every fix',
    () async {
      final controller = build();
      await Future.wait([
        controller.ensureOpen(),
        controller.ensureOpen(),
        controller.ensureOpen(),
      ]);
      expect(location.positionStreamOpenCount, 1);
    },
  );

  test(
    'a second ensureOpen after the first completed does not reopen',
    () async {
      final controller = build();
      await controller.ensureOpen();
      await controller.ensureOpen();
      expect(location.positionStreamOpenCount, 1);
    },
  );

  test('fixes are forwarded to onPosition', () async {
    final controller = build();
    final received = <PositionEntity>[];
    controller.onPosition = received.add;
    await controller.ensureOpen();

    location.fixes.add(fixAt(start));
    await Future<void>.delayed(Duration.zero);

    expect(received.length, 1);
  });

  group('staleness', () {
    test('stale before any fix has ever arrived', () async {
      final controller = build();
      await controller.ensureOpen();
      expect(controller.sinceLastFix, isNull);
      expect(controller.isStale, isTrue);
    });

    test('not stale immediately after a fix', () async {
      final controller = build();
      await controller.ensureOpen();
      location.fixes.add(fixAt(start));
      await Future<void>.delayed(Duration.zero);
      expect(controller.isStale, isFalse);
    });

    test('stale once the threshold elapses with no fix — the OS suspended the '
        'stream in Doze without an error or onDone, so liveness cannot be read '
        'off the subscription', () async {
      final controller = build();
      await controller.ensureOpen();
      location.fixes.add(fixAt(start));
      await Future<void>.delayed(Duration.zero);

      clock.advance(
        PositionStreamController.minimumStaleThreshold +
            const Duration(seconds: 1),
      );
      expect(controller.isStale, isTrue);
      expect(controller.isOpen, isTrue, reason: 'still "open", just silent');
    });

    test('just inside the threshold is still healthy', () async {
      final controller = build();
      await controller.ensureOpen();
      location.fixes.add(fixAt(start));
      await Future<void>.delayed(Duration.zero);

      clock.advance(
        PositionStreamController.minimumStaleThreshold -
            const Duration(seconds: 1),
      );
      expect(controller.isStale, isFalse);
    });

    test('the clock is stamped from raw fixes, not filtered ones', () async {
      // onRawFix must fire for every platform fix; stamping only from fixes that
      // survive the quality gate made "every recent fix was rejected" (normal
      // under tree cover) indistinguishable from a dead stream.
      final controller = build();
      await controller.ensureOpen();
      location.fixes.add(fixAt(start));
      await Future<void>.delayed(Duration.zero);
      expect(controller.lastFixAt, start);
    });
  });

  test('reopen cancels and opens a fresh subscription', () async {
    final controller = build();
    await controller.ensureOpen();
    await controller.reopen();
    expect(location.positionStreamOpenCount, 2);
    expect(controller.isOpen, isTrue);
  });

  test(
    'reenabling location reopens the native stream without a resume',
    () async {
      final controller = build();
      await controller.ensureOpen();
      location.serviceEnabled.add(false);
      location.serviceEnabled.add(false);
      await Future<void>.delayed(Duration.zero);
      await controller.reopen();
      await controller.ensureOpen();
      expect(location.positionStreamOpenCount, 1);

      location.serviceEnabled.add(true);
      location.serviceEnabled.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(location.positionStreamOpenCount, 2);
      final received = <PositionEntity>[];
      controller.onPosition = received.add;
      location.fixes.add(fixAt(start));
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
      await controller.dispose();
    },
  );

  test('service events cannot reopen a disposed controller', () async {
    final controller = build();
    await controller.ensureOpen();
    location.serviceEnabled.add(false);
    await Future<void>.delayed(Duration.zero);
    await controller.dispose();
    location.serviceEnabled.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(location.positionStreamOpenCount, 1);
    expect(location.serviceEnabled.hasListener, isFalse);
  });

  for (final granted in [false, true]) {
    test('recovery with permission $granted is safe across disposal', () async {
      final pending = _PermissionLocation();
      final controller = PositionStreamController(location: pending);
      await controller.ensureOpen();
      pending.serviceEnabled.add(false);
      await Future<void>.delayed(Duration.zero);
      pending.serviceEnabled.add(true);
      await Future<void>.delayed(Duration.zero);
      if (granted) await controller.dispose();
      pending.permission.complete(granted);
      await Future<void>.delayed(Duration.zero);
      expect(pending.positionStreamOpenCount, 1);
      await controller.dispose();
      await pending.dispose();
    });
  }

  test('a disabled stream error waits for service recovery', () async {
    final controller = build();
    await controller.ensureOpen();
    location.fixes.addError(const LocationServiceDisabledException());
    await Future<void>.delayed(Duration.zero);
    await controller.reopen();
    expect(location.positionStreamOpenCount, 1);
    location.serviceEnabled.add(true);
    await Future<void>.delayed(Duration.zero);
    expect(location.positionStreamOpenCount, 2);
    await controller.dispose();
  });

  test('disabling again invalidates a pending recovery', () async {
    final pending = _PermissionLocation();
    final controller = PositionStreamController(location: pending);
    await controller.ensureOpen();
    pending.serviceEnabled.add(false);
    pending.serviceEnabled.add(true);
    await Future<void>.delayed(Duration.zero);
    pending.serviceEnabled.add(false);
    await Future<void>.delayed(Duration.zero);
    pending.permission.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(pending.positionStreamOpenCount, 1);
    await controller.dispose();
    await pending.dispose();
  });

  test(
    'a failed open leaves the controller closed so a later call retries',
    () async {
      final controller = build();
      location.failPositionStream = true;
      await expectLater(controller.ensureOpen(), throwsStateError);
      expect(controller.isOpen, isFalse);

      location.failPositionStream = false;
      await controller.ensureOpen();
      expect(controller.isOpen, isTrue);
    },
  );

  test('dispose cancels the subscription and drops the callbacks', () async {
    final controller = build();
    controller.onPosition = (_) => fail('must not fire after dispose');
    await controller.ensureOpen();
    await controller.dispose();

    expect(controller.isOpen, isFalse);
    location.fixes.add(fixAt(start));
    await Future<void>.delayed(Duration.zero);
  });
}
