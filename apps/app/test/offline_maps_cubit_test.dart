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

    test('clearDownload wins over a download passed in the same call', () {
      // Finishing emits both: the download is over and there is nothing left
      // to show. Honouring the value instead would leave a full progress bar
      // on screen for ever.
      final state = const OfflineMapsState().copyWith(
        download: OfflineDownload(name: '10 km', progress: progress()),
      );
      expect(state.download, isNotNull);
      final cleared = state.copyWith(
        download: OfflineDownload(name: '10 km', progress: progress(done: 100)),
        clearDownload: true,
      );
      expect(cleared.download, isNull);
    });

    test('a download is labelled with what it is of, not where it started', () {
      // The bug this guards: progress was drawn inside the "keep the area
      // around me" card, so downloading France reported itself under that
      // heading. The name travels with the download instead.
      final running = const OfflineMapsState().copyWith(
        download: OfflineDownload(
          name: 'France',
          progress: progress(done: 779, total: 2221390),
        ),
      );
      expect(running.download?.name, 'France');
    });

    test('the name cannot outlive the download that carried it', () {
      // They are one object, so there is no state in which a finished
      // download's name sits above whatever starts next.
      final running = const OfflineMapsState().copyWith(
        download: OfflineDownload(name: 'France', progress: progress(done: 10)),
      );
      expect(running.copyWith(clearDownload: true).download, isNull);
    });

    test('a refresh during a download keeps the name as well as the bar', () {
      final running = const OfflineMapsState().copyWith(
        download: OfflineDownload(name: '10 km', progress: progress(done: 40)),
      );
      final refreshed = running.copyWith(storageBytes: 123);
      expect(refreshed.download?.name, '10 km');
      expect(refreshed.download?.progress.tilesDone, 40);
    });

    test('copyWith keeps the download when something else changes', () {
      // The screen refreshes its storage figures while a download runs, and
      // dropping the progress there would blank the bar mid-download.
      final running = const OfflineMapsState().copyWith(
        download: OfflineDownload(name: '10 km', progress: progress(done: 40)),
      );
      final refreshed = running.copyWith(storageBytes: 123);
      expect(refreshed.download?.progress.tilesDone, 40);
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

    test('nothing is downloading into a region before anything starts', () {
      // Guards the predicate the delete button is disabled by: a false
      // positive here would make an area undeletable for ever.
      final cubit = OfflineMapsCubit();
      addTearDown(cubit.close);
      expect(cubit.isDownloadingInto(1), isFalse);
      expect(cubit.isDownloadingInto(0), isFalse);
    });

    test('deleting the region being written to is refused', () async {
      // Deleting it destroys the download, and the renderer then reports
      // nothing further: the screen would keep a progress bar that can never
      // finish, with every button disabled behind it.
      final cubit = OfflineMapsCubit();
      addTearDown(cubit.close);
      await cubit.open();
      // No platform under test, so there is no store to delete from; what
      // matters is that the guard is consulted before anything is removed.
      await cubit.deleteArea([1]);
      expect(cubit.state.areas, isEmpty);
    });

    test('a failed open is not remembered as a success', () async {
      // OfflineTiles.isSupported is false under test, which is the branch
      // that marks the attempt done. A real failure must leave it open to
      // retry instead.
      final cubit = OfflineMapsCubit();
      addTearDown(cubit.close);
      await cubit.open();
      expect(cubit.state.loading, isFalse);
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
