# recording_session

The recording in progress: what is being recorded, whether it is paused, and
for how long.

## When to use it

Whenever something needs to know, or change, what is being recorded right
now. Three things do — the screen that renders it, the map that reconfigures
the GPS stream from the recording's activity type, and the live share that
follows its pauses — which is why it belongs to none of them.

Watch it; do not keep a copy of what it says.

## Example

```dart
final session = RecordingSession();

await session.start(activityType: ActivityTypeEntity.run);
session.watch().listen((recording) => render(recording.elapsedTime));
await session.score(fix);
await session.pause();
await session.stop();
```

## Owned and borrowed

Owned: the session's state, its elapsed-time timer, and the ordering of its
mutations. Borrowed: the activities capability, which is where recorded
points actually land — this module stores nothing itself.

## Guarantees

**Two queues, and the reason for each.** Starting and cold-start resume share
one: otherwise both can see no activity, await storage, and each install a
different ongoing recording. Mutations — fix, pause, stop — share the other:
at roughly one fix every five seconds there is no throughput to protect, but
two handlers in flight can both read the same last point for gap detection
and each write their own signalLost boundary pair, or clobber each other's
in-memory append. The real case is the OS delivering a backlog of buffered
fixes after a resume.

**`watch()` hands out a buffering stream, not the broadcast one.** A
broadcast stream drops what it emits while a subscriber is paused, and any
subscriber that does work between states — a bloc emitting, a share writing
to a relay — is paused routinely. The state that would be lost is the pause
nobody rendered, or the stop nobody followed.

**What is worth recording is decided here.** A fix must clear the movement
profile's accuracy tolerance to join the active trace; a paused fix is kept
whatever its accuracy, because it marks a segment boundary and contributes
no distance.

The pause and elapsed bookkeeping rebuilt by `resumeOngoing` after an OS kill
is the subtlest logic in the application, and its comments explain why it
reads the last stored point rather than the latest timestamp. Read them
before changing it.

## Verification

`test/recording_session_test.dart` covers the stream contract: emission on
subscription, that a paused subscriber loses nothing, that two subscribers
each receive everything, that the state is readable without subscribing, and
that closing twice is not an error. The state machine itself is covered by
the application's `test/recording_bloc_test.dart`, which drives it through
the adapter and did not change when this module was extracted.
