import 'package:activities/activities.dart';
import 'package:map_view/map_view.dart';

/// Reduces a recording to the lines and markers a map draws.
///
/// The map module takes a [MapTrack] rather than an activity, because two
/// features render it and a shared UI module may not reach a capability.
/// This is the seam: the application knows a recording, the renderer knows
/// polylines, styles and numbered markers.
extension MapTrackView on ActivityEntity {
  /// [milestoneIntervalKm] of zero means no markers, which is the setting a
  /// user picks when they want the track and nothing else.
  MapTrack asMapTrack({int milestoneIntervalKm = 1}) => MapTrack(
    segments: [
      for (final segment in segments)
        MapTrackSegment(
          positions: [for (final point in segment.points) point.position],
          style: _style(segment.status),
        ),
    ],
    milestones: milestoneIntervalKm <= 0
        ? const []
        : [
            for (final milestone in kmMilestonesForInterval(
              milestoneIntervalKm,
            ))
              MapMilestone(
                position: milestone.position,
                label: '${milestone.km}',
              ),
          ],
  );

  static MapTrackStyle _style(ActivityPointStatusEntity status) =>
      switch (status) {
        ActivityPointStatusEntity.active => MapTrackStyle.active,
        ActivityPointStatusEntity.paused => MapTrackStyle.paused,
        ActivityPointStatusEntity.signalLost => MapTrackStyle.signalLost,
      };
}
