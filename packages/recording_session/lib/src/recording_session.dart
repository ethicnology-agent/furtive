import 'dart:async';

import 'package:activities/activities.dart';
import 'package:activity_profile/activity_profile.dart';
import 'package:diagnostics/diagnostics.dart';
import 'package:geo/geo.dart';
import 'package:location/location.dart';
import 'package:wall_clock/wall_clock.dart';

import 'recording_state.dart';

/// The recording in progress: start, pause, stop, resume-after-kill, elapsed
/// time bookkeeping and GPS-outage bracketing.
///
/// Three things watch a recording — the screen that shows it, the map that
/// reconfigures the GPS stream from its activity type, and the live share
/// that follows it — so it cannot belong to any one of them. It is a
/// capability, and the bloc above it is an adapter.
///
/// The pause and elapsed bookkeeping rebuilt by [resumeOngoing] after an OS
/// kill is the subtlest logic in the application. Read its comments before
/// changing it.
class RecordingSession {
  RecordingSession({
    ActivityRepository? activities,
    ScoreActivityUseCase? score,
    EnsureBackgroundTrackingUseCase? ensureBackgroundTracking,
    Clock? clock,
    SignalGapDetector? gapDetector,
  }) : _activities = activities ?? ActivityRepository(clock: clock),
       _score = score ?? ScoreActivityUseCase(),
       _ensureBackgroundTracking =
           ensureBackgroundTracking ?? EnsureBackgroundTrackingUseCase(),
       _clock = clock ?? const SystemClock(),
       _gapDetector = gapDetector ?? SignalGapDetector();

  final ActivityRepository _activities;
  final ScoreActivityUseCase _score;
  final EnsureBackgroundTrackingUseCase _ensureBackgroundTracking;
  final Clock _clock;

  /// Detects GPS outages from the cadence of recorded fixes. Reset on [start]
  /// so one run's cadence never leaks into the next; deliberately NOT reset on
  /// resume-from-kill, where an empty window falls back to the nominal
  /// threshold and still catches the kill-induced gap on the first new fix.
  final SignalGapDetector _gapDetector;

  final _changes = StreamController<RecordingState>.broadcast();
  RecordingState _state = const RecordingState();
  bool _closed = false;

  Timer? _elapsedTimer;
  DateTime? _startedAt;
  DateTime? _pauseStartedAt;
  Duration _completedPauses = Duration.zero;

  /// The recording as it stands.
  RecordingState get state => _state;

  /// The recording now and on every change.
  ///
  /// Emits the current state on subscription, so a subscriber needs no
  /// separate read to get started.
  ///
  /// Each call gets its own buffering stream rather than the broadcast one
  /// directly. A broadcast stream drops what it emits while a subscriber is
  /// paused, and a subscriber that does real work between states — a bloc
  /// emitting, a share writing to a relay — is paused routinely. Dropping a
  /// recording's state is never acceptable: the one lost would be the pause
  /// nobody rendered, or the stop nobody followed.
  Stream<RecordingState> watch() {
    late final StreamController<RecordingState> controller;
    StreamSubscription<RecordingState>? source;
    controller = StreamController<RecordingState>(
      onListen: () {
        controller.add(_state);
        source = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async => source?.cancel(),
    );
    return controller.stream;
  }

  // Two queues, matching the two that bloc's transformers gave before this.
  //
  // Starting and cold-start resume share ONE: per-family serialisation does
  // not coordinate across families, and both could otherwise see a null
  // activity, await storage, and each install a different ongoing recording.
  // Sharing a queue also makes a fast second start a cheap no-op once the
  // first has populated the state.
  //
  // Mutations share the other. At roughly one fix every five seconds there is
  // no throughput to protect, but concurrency here is harmful: two handlers
  // in flight — the OS delivering a backlog of buffered fixes after a resume
  // is the real case — can both capture the same last point for gap detection
  // and each write their own signalLost boundary pair, or clobber each
  // other's in-memory append.
  Future<void>? _initialising;
  Future<void>? _mutating;

  Future<void> _queue(
    Future<void>? Function() read,
    void Function(Future<void>) write,
    Future<void> Function() op,
  ) {
    final previous = read();
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      if (_closed) return;
      await op();
    }();
    write(next);
    return next;
  }

  Future<void> _initialise(Future<void> Function() op) =>
      _queue(() => _initialising, (f) => _initialising = f, op);

  Future<void> _mutate(Future<void> Function() op) =>
      _queue(() => _mutating, (f) => _mutating = f, op);

  /// Picks up a recording the OS killed, if there is one.
  Future<void> resumeOngoing() => _initialise(_onResumeOngoing);

  /// Begins a recording. A no-op if one is already running.
  Future<void> start({
    ActivityTypeEntity activityType = ActivityTypeEntity.unknown,
  }) => _initialise(() => _onStart(activityType));

  /// Records a fix, if it is worth recording. See [_onScoreFix].
  Future<void> score(PositionEntity position) =>
      _mutate(() => _onScoreFix(position));

  /// Pauses a running recording, or resumes a paused one.
  Future<void> pause() => _mutate(_onPause);

  /// Ends the recording.
  Future<void> stop() => _mutate(_onStop);

  /// Reports a GPS outage the caller detected, for the screen to surface.
  void reportTrackingGap(Duration gap) =>
      _emit(_state.copyWith(trackingGap: gap));

  void clearTrackingGap() => _emit(_state.copyWith(trackingGap: null));

  void clearError() => _emit(_state.copyWith(error: null));

  /// Recomputes the elapsed time from the clock.
  ///
  /// Driven by this session's own timer once a recording is running. Public
  /// so a test can advance a [FixedClock] and step the elapsed time without
  /// waiting a real second for each one.
  void tick() => _onTick();

  /// Releases the timer and the change stream. Safe to call twice: the
  /// adapter closes the session it renders, and the composition root disposes
  /// the one it owns.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _elapsedTimer?.cancel();
    await _changes.close();
  }

  void _emit(RecordingState next) {
    if (_closed) return;
    _state = next;
    _changes.add(next);
  }

  void _startTicking() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_closed) _onTick();
    });
  }

  Future<void> _onResumeOngoing() async {
    if (_state.activity != null) return;
    try {
      final ongoing = await _activities.fetchOngoing();
      if (ongoing == null) return;

      // Rebuild the timing bookkeeping the in-memory bloc lost on the kill.
      // startedAt is authoritative; completed-pause time comes from the
      // persisted point statuses (the same calc the stats use).
      _startedAt = ongoing.startedAt;
      _completedPauses = ongoing.pausedDuration;
      _pauseStartedAt = null;

      // Prefer the durable pause/resume checkpoint. Legacy activities have no
      // checkpoint yet and fall back to the last recorded point. Staying
      // paused keeps the dead gap out of active
      // elapsed time; if it was active, the gap counts as elapsed (the run was
      // notionally still going, just with no GPS) which is the honest reading.
      //
      // `points.last`, NOT `firstWhere(time == max(time))`. fetchOngoing orders
      // by `id ASC`, i.e. insertion order, so the last element IS the last fix
      // recorded. Selecting by maximum timestamp instead is wrong whenever the
      // final points share a timestamp — and they routinely do: SQLite truncates
      // DateTime to whole seconds, so the ±1µs signalLost boundary pair that
      // brackets a GPS outage collapses into an exact tie with the fix beside it
      // (the same truncation that forces the stable mergeSort in
      // activity_entity.dart). firstWhere would then return the *earliest* point
      // of the tie — typically a signalLost boundary — and read its status
      // instead of the real last fix's. A run killed while paused right after an
      // outage would resume UNPAUSED, restarting the timer and counting the dead
      // time as active.
      final lastPoint = ongoing.points.isEmpty ? null : ongoing.points.last;

      final Duration elapsed;
      final checkpoint = await _activities.fetchRecordingCheckpoint(ongoing.id);
      if (checkpoint != null) {
        _completedPauses = checkpoint.completedPauses;
        _pauseStartedAt = checkpoint.pausedAt;
        elapsed =
            (checkpoint.pausedAt ?? _clock.nowUtc()).difference(_startedAt!) -
            _completedPauses;
        if (checkpoint.pausedAt == null) _startTicking();
      } else if (lastPoint != null &&
          lastPoint.status == ActivityPointStatusEntity.paused) {
        // Continue the ongoing pause from the last fix. _completedPauses already
        // covers up to that fix, so resuming adds (now - lastFix) without double
        // counting. Freeze elapsed at the pause moment; no timer while paused.
        _pauseStartedAt = lastPoint.time;
        elapsed = lastPoint.time.difference(_startedAt!) - _completedPauses;
      } else {
        _startTicking();
        elapsed = _clock.nowUtc().difference(_startedAt!) - _completedPauses;
      }

      final wasPaused = _pauseStartedAt != null;
      logs.fine(
        'Resumed ongoing activity ${ongoing.id} from storage '
        '(paused: $wasPaused).',
      );
      _emit(
        _state.copyWith(
          activity: ongoing,
          isPaused: wasPaused,
          elapsedTime: elapsed.isNegative ? Duration.zero : elapsed,
        ),
      );
    } catch (e, s) {
      // A failed resume must not block the map from loading.
      logs.severe('resumeOngoingRecording', error: e, trace: s);
    }
  }

  Future<void> _onStart(ActivityTypeEntity activityType) async {
    // Defence in depth alongside droppable(): a recording is already running,
    // so a Start here is a no-op rather than a second concurrent activity.
    if (_state.activity != null) return;
    try {
      _emit(_state.copyWith(isStarting: true, error: null));

      // Ask for the battery-optimisation exemption before recording begins so
      // the foreground service survives a locked screen on aggressive OEMs.
      // Best-effort: a denial still starts the run (FGS + wake lock remain).
      if (!await _ensureBackgroundTracking()) {
        logs.warning(
          'Battery optimisation exemption not granted; tracking may stop '
          'while the phone is locked on aggressive OEMs.',
        );
      }

      _elapsedTimer?.cancel();
      _pauseStartedAt = null;
      _completedPauses = Duration.zero;
      _gapDetector.reset();

      final activity = await _activities.startNew(activityType: activityType);
      logs.info(
        'StartRecording: activity ${activity.id} started at '
        '${activity.startedAt} as ${activity.activityType.name}',
      );
      _startedAt = activity.startedAt;
      _startTicking();

      _emit(_state.copyWith(activity: activity));
    } catch (e, s) {
      logs.severe('start', error: e, trace: s);
      _emit(_state.copyWith(error: AppError(e.toString())));
    } finally {
      _emit(_state.copyWith(isStarting: false));
    }
  }

  Future<void> _onScoreFix(PositionEntity position) async {
    // A stop can be processed between the fix arriving and this handler running,
    // nulling _state.activity. Return rather than throwing.
    final activity = _state.activity;
    if (activity == null) return;
    final status = _state.isPaused
        ? ActivityPointStatusEntity.paused
        : ActivityPointStatusEntity.active;

    // Whether a fix is good enough to record is the recorder's decision, and
    // it is made here rather than by whoever hands the fix over. The map used
    // to make it before forwarding, which meant a screen had to know the
    // movement profile's tolerance to feed the recording correctly.
    //
    // The map's stream deliberately admits one vague fix after a sustained
    // bad-signal spell so the cursor degrades instead of freezing. That is a
    // presentation policy, and it is not permission to inflate the active
    // trace. Paused points remain writable even when vague: they establish
    // the active<->paused segment boundary and never contribute to distance.
    if (status == ActivityPointStatusEntity.active) {
      final tuning = activity.activityType.movementProfile.tuning;
      if (!tuning.acceptsAccuracy(position.accuracy)) {
        logs.warning(
          'Skipped an active fix outside the '
          '${tuning.accuracyToleranceMeters.toStringAsFixed(0)} m recording '
          'tolerance (accuracy '
          '${position.accuracy?.toStringAsFixed(1) ?? 'unknown'} m).',
        );
        return;
      }
    }

    // Outage detection runs only between two consecutive *active* fixes: a pause
    // already excludes its time from active stats, and the active<->paused
    // transition is an inter-segment gap that is never counted. The check uses
    // the fix's own timestamp (the same source the stored point gets) so a
    // queued/delayed handler cannot fabricate a gap.
    ActivityPointEntity? gapFrom;
    final previous = activity.points.isEmpty ? null : activity.points.last;
    if (previous != null &&
        previous.status == ActivityPointStatusEntity.active &&
        status == ActivityPointStatusEntity.active) {
      final fixTime = position.time ?? _clock.nowUtc();
      final gap = _gapDetector.check(previous.time, fixTime);
      if (gap != null) {
        gapFrom = previous;
        logs.warning(
          'ScoreFix: GPS outage of ${gap.inSeconds}s detected on activity '
          '${activity.id} (threshold ${_gapDetector.threshold.inSeconds}s) — '
          'bracketing with signalLost boundary points.',
        );
      }
    }

    try {
      final newPoints = await _score(
        activityId: activity.id,
        position: position,
        status: status,
        gapFrom: gapFrom,
      );
      // Append to the LATEST in-memory activity, not the pre-await capture:
      // concurrent handlers would otherwise each append to the same stale list
      // and clobber one another. If a stop landed during the await, skip.
      final current = _state.activity;
      if (current == null || current.id != activity.id) return;
      final pointCount = current.points.length + newPoints.length;
      // Heartbeat, not one line per fix (every ~5 s would flood the log over a
      // long activity) — roughly one line a minute, so a walk's continuity (or
      // a silent gap) stays visible in the exported logs.
      if (pointCount % 12 == 0) {
        logs.fine(
          'ScoreFix: activity ${activity.id} has $pointCount points '
          '(status: ${status.name}).',
        );
      }
      final updated = current.copyWith(
        points: [...current.points, ...newPoints],
      );
      // Computing these also warms ActivityEntity's per-instance stats cache for
      // the map rebuild. Persisting them keeps the Activities tab from loading
      // the full in-progress trace just to render one summary row.
      final liveDistance = updated.activeDistanceMeters;
      final liveDuration = updated.activeDuration;
      _emit(_state.copyWith(activity: updated));
      try {
        await _activities.updateLiveAggregates(
          activity.id,
          distanceMeters: liveDistance,
          activeDuration: liveDuration,
        );
      } catch (e, s) {
        // The point itself is already durable. A stale list summary is not a
        // reason to report that recording failed; cease() recomputes it later.
        logs.warning('update live activity aggregates', error: e, trace: s);
      }
    } catch (e, s) {
      logs.severe('score', error: e, trace: s);
      _emit(_state.copyWith(error: AppError('ScoreFix: $e')));
    }
  }

  Future<void> _onPause() async {
    final activity = _state.activity;
    if (activity == null) return;

    final wasPaused = _state.isPaused;
    final now = _clock.nowUtc();
    final completedPauses =
        _completedPauses +
        (wasPaused && _pauseStartedAt != null
            ? now.difference(_pauseStartedAt!)
            : Duration.zero);
    final pausedAt = wasPaused ? null : now;
    try {
      await _activities.saveRecordingCheckpoint(
        activity.id,
        pausedAt: pausedAt,
        completedPauses: completedPauses,
      );
    } catch (e, s) {
      logs.severe('Persist recording pause', error: e, trace: s);
      _emit(_state.copyWith(error: AppError(e.toString())));
      return;
    }
    _completedPauses = completedPauses;
    _pauseStartedAt = pausedAt;
    logs.info(
      'PauseRecording: activity ${_state.activity!.id} '
      '${wasPaused ? 'resumed' : 'paused'} at elapsed '
      '${_state.elapsedTime.inSeconds}s.',
    );

    if (wasPaused) {
      _startTicking();
    } else {
      _elapsedTimer?.cancel();
    }

    final elapsed = now.difference(_startedAt!) - completedPauses;
    _emit(
      _state.copyWith(
        isPaused: !wasPaused,
        elapsedTime: elapsed.isNegative ? Duration.zero : elapsed,
      ),
    );
  }

  Future<void> _onStop() async {
    // Back-to-back Stop taps would hit a null activity on the second pass.
    final activity = _state.activity;
    if (activity == null) return;
    try {
      await _activities.cease(activity.id);
      logs.info(
        'StopRecording: activity ${activity.id} stopped with '
        '${activity.points.length} points, elapsed '
        '${_state.elapsedTime.inSeconds}s.',
      );
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
      _startedAt = null;
      _pauseStartedAt = null;
      _completedPauses = Duration.zero;

      _emit(
        _state.copyWith(
          activity: null,
          elapsedTime: Duration.zero,
          isPaused: false,
        ),
      );
    } catch (e, s) {
      logs.severe('stop', error: e, trace: s);
      _emit(_state.copyWith(error: AppError(e.toString())));
    }
  }

  void _onTick() {
    final startedAt = _startedAt;
    if (startedAt == null || _state.isPaused) return;
    final elapsed = _clock.nowUtc().difference(startedAt) - _completedPauses;
    _emit(
      _state.copyWith(
        elapsedTime: elapsed.isNegative ? Duration.zero : elapsed,
      ),
    );
  }
}
