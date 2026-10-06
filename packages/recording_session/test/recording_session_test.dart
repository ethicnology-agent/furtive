import 'package:flutter_test/flutter_test.dart';
import 'package:recording_session/recording_session.dart';

void main() {
  late RecordingSession subject;

  setUp(() => subject = RecordingSession());
  tearDown(() => subject.close());

  test('watch emits the current state on subscription', () async {
    expect((await subject.watch().first).activity, isNull);
  });

  test('a subscriber that pauses does not lose a state', () async {
    // The reason watch hands out a buffering stream rather than the broadcast
    // one. A broadcast stream drops what it emits while a subscriber is
    // paused, and any subscriber doing real work between states — a bloc
    // emitting, a share writing to a relay — is paused routinely. This failed
    // before the buffer: the gap below never arrived.
    final seen = <Duration?>[];
    final subscription = subject.watch().listen((s) => seen.add(s.trackingGap));
    subscription.pause();

    subject.reportTrackingGap(const Duration(minutes: 4));
    subject.clearTrackingGap();
    subscription.resume();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(seen, [null, const Duration(minutes: 4), null]);
  });

  test('two subscribers each receive every state', () async {
    final first = <Duration?>[];
    final second = <Duration?>[];
    final a = subject.watch().listen((s) => first.add(s.trackingGap));
    final b = subject.watch().listen((s) => second.add(s.trackingGap));

    subject.reportTrackingGap(const Duration(minutes: 2));
    await Future<void>.delayed(Duration.zero);
    await a.cancel();
    await b.cancel();

    expect(first, [null, const Duration(minutes: 2)]);
    expect(second, first);
  });

  test('the state is readable without subscribing', () {
    // The map asks what is being recorded on a hot path; it should not have
    // to hold a subscription to answer.
    subject.reportTrackingGap(const Duration(minutes: 1));

    expect(subject.state.trackingGap, const Duration(minutes: 1));
  });

  test('closing twice is not an error', () async {
    // The adapter closes the session it renders, and the composition root
    // disposes the one it owns; both can happen on the same instance.
    await subject.close();

    await expectLater(subject.close(), completes);
  });

  test('a closed session stops emitting', () async {
    final seen = <Duration?>[];
    subject.watch().listen((s) => seen.add(s.trackingGap));
    await subject.close();

    subject.reportTrackingGap(const Duration(minutes: 9));
    await Future<void>.delayed(Duration.zero);

    expect(seen, isNot(contains(const Duration(minutes: 9))));
  });
}
