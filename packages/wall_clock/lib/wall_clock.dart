/// Injectable source of "now".
///
/// Exists so the app's time-dependent behaviour is testable without waiting in
/// real time. Furtive has several windows that are otherwise unreachable from a
/// test: the 12 h after which an unfinished recording is treated as abandoned
/// rather than resumable (`ActivityLocalDataSource.ongoingStaleAfter`), the 20 s
/// of silence after which the position stream is assumed suspended
/// (`PositionStreamController.staleThreshold`), the 24 h update-check TTL, and
/// all of the elapsed/paused-duration bookkeeping during a recording.
///
/// Everything in the app that needs the wall clock takes a [Clock] rather than
/// calling `DateTime.now()` directly. Production code gets [SystemClock] by
/// default, so call sites stay unchanged; tests pass a [FixedClock] (or their
/// own implementation) and drive time explicitly.
///
/// It sits below every capability because recording, the map, the live
/// share and the activity store all read the clock, and none of them may
/// depend on another.
library;

export 'src/clock.dart';
