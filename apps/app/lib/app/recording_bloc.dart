import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/app/recording_event.dart';
import 'package:recording_session/recording_session.dart';

/// A bloc-shaped view of [RecordingSession], for the widgets that render it.
///
/// The state machine itself is a capability: the map reconfigures the GPS
/// stream from the recording's activity type and the live share follows its
/// pauses. What is left here is the translation between a widget's events and
/// a session's methods, and a stream Flutter can rebuild from.
///
/// It is the shell's, not a feature's. Once the state machine left, a
/// `recording` feature with no page, no widget and no journey was two files
/// of adapter that another feature's page imported — which is how `map ->
/// recording` survived. A presentation adapter over a shared capability is
/// glue, and glue belongs where the composition happens.
///
/// Every command handler returns without awaiting on purpose. The session
/// serialises its own work on two queues — ordering is its guarantee, not
/// this adapter's — and awaiting here would only hold a bloc event open for
/// the duration.
class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  RecordingBloc({RecordingSession? session})
    : _session = session ?? RecordingSession(),
      super(const RecordingState()) {
    // The session's emissions reach this bloc through a handler that never
    // returns rather than by re-adding each one as an event. A bloc may only
    // emit from inside a handler, and routing a subscription back through
    // `add` means the emission is queued behind whatever event caused it —
    // which silently drops it when the cause was a command this bloc is
    // still processing.
    on<WatchSession>(
      (_, emit) => emit.onEach(_session.watch(), onData: emit.call),
    );
    on<ResumeOngoingRecording>((_, _) => _session.resumeOngoing());
    on<StartRecording>(
      (event, _) => _session.start(activityType: event.activityType),
    );
    on<PauseRecording>((_, _) => _session.pause());
    on<StopRecording>((_, _) => _session.stop());
    on<ScoreFix>((event, _) => _session.score(event.position));
    on<TickElapsed>((_, _) => _session.tick());
    on<ReportTrackingGap>((event, _) => _session.reportTrackingGap(event.gap));
    on<ClearTrackingGap>((_, _) => _session.clearTrackingGap());
    on<ClearRecordingError>((_, _) => _session.clearError());

    add(const WatchSession());
  }

  final RecordingSession _session;

  /// The session this bloc renders, for whatever owns it.
  RecordingSession get session => _session;

  @override
  Future<void> close() async {
    await _session.close();
    return super.close();
  }
}
