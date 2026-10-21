import 'package:activity_profile/activity_profile.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:diagnostics/diagnostics.dart';
import 'package:furtive/features/map/bloc/map_bloc.dart';
import 'package:geo/geo.dart';

part 'map_state.mapper.dart';

/// Map presentation state only. Everything about the in-progress recording
/// (activity, elapsed time, pause, tracking gap) lives in RecordingState.
@MappableClass()
class MapState with MapStateMappable {
  const MapState({
    this.styleUrl,
    this.userLocation,
    this.error,
    this.loadingStatus,
    this.isFollowingUser = false,
    this.selectedActivityType = ActivityTypeEntity.walk,
    this.recordingDetail = RecordingDetailEntity.balanced,
    this.mapControlsOnLeft = false,
    this.mapMilestoneIntervalKm = 1,
    this.deviceHeading,
    this.locationServiceEnabled,
  });

  /// Resolved basemap style URL, or null for a tileless map (no PROTOMAPS_KEY
  /// compiled in, or the user opted out of tile fetches). A URL rather than a
  /// parsed style because MapLibre Native fetches and parses it itself.
  final String? styleUrl;
  final PositionEntity? userLocation;
  final AppError? error;
  final LoadingStatus? loadingStatus;

  /// Whether the camera follows the user's position.
  final bool isFollowingUser;

  /// What the next recording will be started as. Seeded from the last
  /// recorded type and changed from the record screen, so the common case
  /// (doing the same thing as last time) costs no interaction at all.
  final ActivityTypeEntity selectedActivityType;

  /// Sampling density preference, applied on top of the activity's profile.
  final RecordingDetailEntity recordingDetail;

  /// Whether the floating map controls sit on the left. Presentation only.
  final bool mapControlsOnLeft;

  /// Distance between numbered route markers. Zero hides them.
  final int mapMilestoneIntervalKm;

  /// Which way the device is pointing, degrees clockwise from true north, or
  /// null when no compass is available. Deliberately not the same thing as
  /// `userLocation.heading`, which is the direction of travel.
  final double? deviceHeading;

  /// Whether the device's location service is switched on, or null while
  /// unknown.
  ///
  /// Distinct from "no fix yet". A cold GPS that has not warmed up will
  /// deliver on its own and deserves silence; a service that is off never
  /// will, and the user is the only one who can change that. Conflating the
  /// two is what let the application wait indefinitely while saying nothing.
  final bool? locationServiceEnabled;
}
