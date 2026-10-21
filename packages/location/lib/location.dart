/// The device's position stream, filtered for the activity being recorded.
///
/// A GPS receiver reports more than it knows. Fixes arrive with accuracies
/// the platform guessed at, speeds that are multipath rather than movement,
/// bearings emitted while standing still, and stretches of nothing at all
/// when the sky is behind concrete. This module turns that into a stream a
/// recorder can trust, and says when it has stopped arriving.
library;

export 'src/compass_facade.dart';
export 'src/ensure_background_tracking_use_case.dart';
export 'src/gps_quality_filter.dart';
export 'src/location_repository.dart';
export 'src/position_stream_controller.dart';
export 'src/signal_gap_detector.dart';
