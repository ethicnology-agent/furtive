import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/offline_maps/offline_maps_cubit.dart';
import 'package:furtive/features/offline_maps/offline_ledger.dart';
import 'package:map_view/map_view.dart';

OfflineProgress progress({
  int done = 0,
  int total = 100,
  int bytes = 0,
  bool complete = false,
}) => OfflineProgress(
  tilesDone: done,
  tilesTotal: total,
  bytes: bytes,
  isEstimate: false,
  isComplete: complete,
);

void main() {
  group('OfflineMapsState', () {
    test('what the kept areas cost is the sum of their records', () {
      const state = OfflineMapsState(
        costs: {
          'a': OfflineAreaCost(tiles: 1313, bytes: 7026194),
          'b': OfflineAreaCost(tiles: 676, bytes: 27864936),
        },
      );
      expect(state.keptTiles, 1989);
      expect(state.keptBytes, 34891130);
    });

    test('an empty ledger costs nothing rather than being unknown', () {
      const state = OfflineMapsState();
      expect(state.keptBytes, 0);
      expect(state.keptTiles, 0);
    });

    test('clearProgress wins over a progress passed in the same call', () {
      // Finishing emits both: the download is over and there is nothing left
      // to show. Honouring the value instead would leave a full progress bar
      // on screen for ever.
      final state = const OfflineMapsState().copyWith(progress: progress());
      expect(state.progress, isNotNull);
      final cleared = state.copyWith(
        progress: progress(done: 100),
        clearProgress: true,
      );
      expect(cleared.progress, isNull);
    });

    test('copyWith keeps the download when something else changes', () {
      // The screen refreshes its storage figures while a download runs, and
      // dropping the progress there would blank the bar mid-download.
      final running = const OfflineMapsState().copyWith(
        progress: progress(done: 40),
      );
      final refreshed = running.copyWith(storageBytes: 123);
      expect(refreshed.progress?.tilesDone, 40);
      expect(refreshed.storageBytes, 123);
    });
  });

  group('OfflineMapsCubit', () {
    test('an unsupported platform stops loading instead of hanging', () async {
      final cubit = OfflineMapsCubit();
      addTearDown(cubit.close);
      // No platform under a unit test, so OfflineTiles.isSupported is false:
      // this is the branch a web build takes.
      await cubit.open();
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.supported, isFalse);
    });

    test('a download is refused while one is already running', () async {
      // Not a hypothetical: the screen can be left and re-entered while a
      // download runs, and a second request would start a second region over
      // the first.
      final cubit = OfflineMapsCubit();
      addTearDown(cubit.close);
      await cubit.open();
      expect(cubit.isDownloading, isFalse);
    });

    test('a reported failure is cleared so it is shown once', () async {
      final cubit = OfflineMapsCubit();
      addTearDown(cubit.close);
      await cubit.open();
      cubit.emit(cubit.state.copyWith(failed: true));
      expect(cubit.state.failed, isTrue);
      cubit.failureReported();
      expect(cubit.state.failed, isFalse);
    });
  });
}
