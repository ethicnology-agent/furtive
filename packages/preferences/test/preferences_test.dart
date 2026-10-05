import 'package:activity_profile/activity_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';

void main() {
  late PreferencesRepository subject;

  setUp(() => subject = PreferencesRepository.inMemory());
  tearDown(() => subject.close());

  test('a store nobody has written reports the defaults', () async {
    final read = await subject.fetch();

    expect(read.mapTheme, MapThemeEntity.dark);
    expect(read.hasCompletedOnboarding, isFalse);
    expect(read.uiLocale, isNull);
    expect(read.lastShownChangelogVersion, isNull);
    expect(read.mapTilesEnabled, isTrue);
    expect(read.showOnLockScreen, isTrue);
    expect(read.mapControlsOnLeft, isFalse);
    expect(read.lastActivityType, ActivityTypeEntity.walk);
    expect(read.recordingDetail, RecordingDetailEntity.balanced);
  });

  test('reading does not write', () async {
    // The handover depends on this: a store is "empty" until someone stores
    // something, and a startup read must not be what fills it.
    await subject.fetch();

    expect(await subject.adoptIfEmpty(_carried), isTrue);
    expect((await subject.fetch()).uiLocale, 'de');
  });

  test('a round trip preserves every field', () async {
    await subject.store(_carried);

    final read = await subject.fetch();
    expect(read.mapTheme, MapThemeEntity.white);
    expect(read.hasCompletedOnboarding, isTrue);
    expect(read.uiLocale, 'de');
    expect(read.lastShownChangelogVersion, '1.2.0');
    expect(read.mapTilesEnabled, isFalse);
    expect(read.showOnLockScreen, isFalse);
    expect(read.mapControlsOnLeft, isTrue);
    expect(read.mapMilestoneIntervalKm, 50);
    expect(read.lastActivityType, ActivityTypeEntity.bike);
    expect(read.recordingDetail, RecordingDetailEntity.precise);
  });

  group('adoptIfEmpty', () {
    test('takes settings over when nothing has been stored', () async {
      expect(await subject.adoptIfEmpty(_carried), isTrue);
      expect((await subject.fetch()).mapTheme, MapThemeEntity.white);
    });

    test('refuses once anything has been stored', () async {
      await subject.store((await subject.fetch()).copyWith(uiLocale: 'fr'));

      expect(await subject.adoptIfEmpty(_carried), isFalse);
      expect(
        (await subject.fetch()).uiLocale,
        'fr',
        reason: 'what the user chose must survive a stale handover',
      );
    });

    test(
      'refuses a second time, so a rerun cannot roll settings back',
      () async {
        await subject.adoptIfEmpty(_carried);
        await subject.store(
          (await subject.fetch()).copyWith(mapTheme: MapThemeEntity.black),
        );

        expect(await subject.adoptIfEmpty(_carried), isFalse);
        expect((await subject.fetch()).mapTheme, MapThemeEntity.black);
      },
    );
  });
}

final _carried = PreferencesEntity(
  mapTheme: MapThemeEntity.white,
  hasCompletedOnboarding: true,
  uiLocale: 'de',
  lastShownChangelogVersion: '1.2.0',
  mapTilesEnabled: false,
  showOnLockScreen: false,
  mapControlsOnLeft: true,
  mapMilestoneIntervalKm: 50,
  lastActivityType: ActivityTypeEntity.bike,
  recordingDetail: RecordingDetailEntity.precise,
);
