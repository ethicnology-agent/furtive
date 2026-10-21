/// The recording in progress.
///
/// Three things watch a recording — the screen that shows it, the map that
/// reconfigures the GPS stream from its activity type, and the live share
/// that follows it — so it belongs to none of them. Watch it and command it;
/// do not hold a copy of what it says.
library;

export 'src/recording_session.dart';
export 'src/recording_state.dart';
