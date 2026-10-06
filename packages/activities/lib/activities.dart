/// Recorded activities: their points, the statistics derived from them, and
/// the database they live in.
///
/// A recording is a sequence of GPS fixes split into segments by what the
/// recorder was doing — moving, paused, or without signal — and almost
/// everything a screen shows about it is derived from those segments rather
/// than stored: distance, duration, pace, elevation gain, kilometre splits.
library;

export 'src/activity_entity.dart';
export 'src/activity_repository.dart';
export 'src/activity_summary.dart';
export 'src/score_activity_use_case.dart';
