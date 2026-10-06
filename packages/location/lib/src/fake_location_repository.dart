import 'dart:async';

import 'package:activity_profile/activity_profile.dart';
import 'package:geo/geo.dart';
import 'package:geolocator/geolocator.dart';

import 'location_gps_data_source.dart';
import 'location_repository.dart';

/// Hand-written, deliberately not a generated mock.
///
/// The seams this module exposes are few and narrow, so an explicit fake
/// reads better than a generated one, needs no build step, and never
/// silently stubs a method the production code started depending on.

/// A [LocationRepository] whose fix stream and one-shot fix are fully driven by
/// the test. Overrides the repository rather than the datasource because the
/// repository is what consumers depend on, and its own logic (non-finite
/// filtering, GpsQualityFilter) is already covered by its own tests.
class FakeLocationRepository extends LocationRepository {
  FakeLocationRepository({
    this.currentLocation,
    this.failCurrentLocation = false,
  }) : super(gps: _UnusedGpsDataSource());

  /// Emit onto this to deliver fixes to whatever opened the stream.
  final StreamController<PositionEntity> fixes =
      StreamController<PositionEntity>.broadcast();
  final StreamController<bool> serviceEnabled =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> getServiceEnabledStream() => serviceEnabled.stream;

  @override
  Future<bool> checkLocationPermission() async => true;

  /// Returned by [getCurrentLocation] unless [failCurrentLocation].
  PositionEntity? currentLocation;

  /// When true, [getCurrentLocation] throws — the real-world "GPS not warmed up
  /// right after an unlock" case that must not block a resume.
  bool failCurrentLocation;

  /// Set true to make [getPositionStream] throw, simulating a stream that can't
  /// be opened at all.
  bool failPositionStream = false;
  int positionStreamFailuresRemaining = 0;

  int positionStreamOpenCount = 0;
  int positionStreamOpenAttempts = 0;
  int batteryExemptionRequests = 0;
  bool batteryOptimizationDisabled = true;

  @override
  Future<PositionEntity> getCurrentLocation() async {
    if (failCurrentLocation || currentLocation == null) {
      throw StateError('no fix available');
    }
    return currentLocation!;
  }

  /// Tuning the last [getPositionStream] call was opened with, so a test can
  /// assert that starting an activity actually re-opened the stream with the
  /// chosen profile rather than silently keeping the map's generic one.
  MovementTuning? lastTuning;
  RecordingDetailEntity? lastDetail;

  @override
  Stream<PositionEntity> getPositionStream({
    void Function()? onRawFix,
    MovementTuning? tuning,
    RecordingDetailEntity detail = RecordingDetailEntity.balanced,
  }) {
    positionStreamOpenAttempts++;
    if (failPositionStream || positionStreamFailuresRemaining > 0) {
      if (positionStreamFailuresRemaining > 0) {
        positionStreamFailuresRemaining--;
      }
      throw StateError('cannot open stream');
    }
    positionStreamOpenCount++;
    lastTuning = tuning;
    lastDetail = detail;
    return fixes.stream.map((p) {
      onRawFix?.call();
      return p;
    });
  }

  @override
  Future<bool> isBatteryOptimizationDisabled() async =>
      batteryOptimizationDisabled;

  @override
  Future<bool> requestDisableBatteryOptimization() async {
    batteryExemptionRequests++;
    return batteryOptimizationDisabled;
  }

  Future<void> dispose() async {
    await fixes.close();
    await serviceEnabled.close();
  }
}

/// Never called: [FakeLocationRepository] overrides every method that would
/// reach the datasource. Exists only to satisfy the super constructor without
/// touching a real platform channel.
class _UnusedGpsDataSource implements LocationGpsDataSource {
  @override
  Never noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('the fake repository should not reach the GPS');
}

/// Convenience builder for a position at a given time.
PositionEntity fixAt(
  DateTime time, {
  double latitude = 48.85,
  double longitude = 2.35,
  double elevation = 0,
  double? accuracy,
  double? verticalAccuracy,
}) => PositionEntity(
  latitude: latitude,
  longitude: longitude,
  elevation: elevation,
  time: time,
  accuracy: accuracy,
  verticalAccuracy: verticalAccuracy,
);

/// Unused import guard: keeps the geolocator import meaningful if a future fake
/// needs to build a raw [Position].
typedef RawPosition = Position;
