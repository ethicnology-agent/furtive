import 'dart:async';

import 'package:diagnostics/diagnostics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/offline_maps/map_storage.dart';
import 'package:furtive/features/offline_maps/offline_ledger.dart';
import 'package:furtive/features/offline_maps/superseded_areas.dart';
import 'package:geo/geo.dart';
import 'package:map_view/map_view.dart';

/// A download in flight: what it is of, and how far it has got.
///
/// One object rather than two fields on the state, because the two have to
/// agree. Held separately, clearing the progress had to remember to clear
/// the name with it, and starting a download had to emit twice — once to
/// clear, once to name — because a single copyWith could not express both.
class OfflineDownload {
  const OfflineDownload({required this.name, required this.progress});

  /// As the user asked for it: "10 km", or "France".
  final String name;

  final OfflineProgress progress;

  OfflineDownload at(OfflineProgress progress) =>
      OfflineDownload(name: name, progress: progress);
}

/// What the offline maps screen shows, and the download it is watching.
class OfflineMapsState {
  const OfflineMapsState({
    this.loading = true,
    this.supported = true,
    this.areas = const [],
    this.costs = const {},
    this.storageBytes,
    this.download,
    this.failed = false,
  });

  final bool loading;
  final bool supported;
  final List<OfflineArea> areas;
  final Map<String, OfflineAreaCost> costs;
  final int? storageBytes;

  /// The download in flight, or null when none is.
  final OfflineDownload? download;

  /// Raised once when a download fails, cleared by whoever reported it.
  final bool failed;

  OfflineMapsState copyWith({
    bool? loading,
    bool? supported,
    List<OfflineArea>? areas,
    Map<String, OfflineAreaCost>? costs,
    int? storageBytes,
    OfflineDownload? download,
    bool clearDownload = false,
    bool? failed,
  }) => OfflineMapsState(
    loading: loading ?? this.loading,
    supported: supported ?? this.supported,
    areas: areas ?? this.areas,
    costs: costs ?? this.costs,
    storageBytes: storageBytes ?? this.storageBytes,
    download: clearDownload ? null : download ?? this.download,
    failed: failed ?? this.failed,
  );

  int get keptBytes => costs.values.fold(0, (sum, cost) => sum + cost.bytes);

  int get keptTiles => costs.values.fold(0, (sum, cost) => sum + cost.tiles);
}

/// Owns the tile store and whatever download is running.
///
/// A process-scoped singleton rather than screen state, because a download
/// outliving its screen is the whole point. When this lived in the page,
/// leaving it disposed the manager and the download stopped — measured on an
/// Android 12 device: the database kept growing for about twenty seconds
/// after the manager went away, the tail of requests already in flight, then
/// stayed at exactly the same size for the next eighty. A 50 km download
/// abandoned at a fifth of its tiles.
///
/// Backgrounding the app is a different matter and needs nothing: with the
/// process alive the same download kept writing through ninety seconds off
/// screen, at the rate it had before. What kills a download is losing the
/// manager, not losing the foreground.
class OfflineMapsCubit extends Cubit<OfflineMapsState> {
  OfflineMapsCubit() : super(const OfflineMapsState());

  OfflineTiles? _tiles;
  OfflineLedger? _ledger;
  StreamSubscription<OfflineProgress>? _download;

  /// The identity of the download in flight, kept so its leftovers can be
  /// swept once it finishes.
  String? _downloadKey;

  /// The region the running download is writing into, learned from its first
  /// progress event. Deleting that region destroys the download, and the
  /// renderer then reports nothing further — so the screen would sit on a
  /// progress bar that can never finish.
  int? _downloadRegionId;

  /// When the running download last wrote its cost down.
  ///
  /// It is written as it goes, not only at the end, so that killing the app
  /// mid-download leaves the area accounted for rather than listed with
  /// nothing beside it. Throttled because progress arrives several times a
  /// second and this is a file.
  DateTime? _lastRecorded;
  static const _recordEvery = Duration(seconds: 5);

  bool _opened = false;

  /// Prepares the store. Safe to call on every visit to the screen; the work
  /// happens once, and a download already running is left alone.
  ///
  /// A failure here is not remembered as success. Marking the attempt done
  /// before it had worked meant one bad open left the store null for the
  /// life of the process: the screen kept its spinner, and coming back only
  /// ever called [refresh], so the buttons were silently dead until the app
  /// was restarted.
  Future<void> open() async {
    if (_opened) {
      await refresh();
      return;
    }
    if (!OfflineTiles.isSupported) {
      _opened = true;
      emit(state.copyWith(loading: false, supported: false));
      return;
    }
    try {
      final tiles = await OfflineTiles.create();
      _tiles = tiles;
      // Also set at startup; repeated here so this screen works even if that
      // pass failed.
      unawaited(tiles.setMaximumCacheSize(ambientCacheBudgetBytes));
      _ledger = OfflineLedger(await offlineLedgerFile());
      _opened = true;
      await refresh();
    } on Object catch (error, stack) {
      logs.severe('Offline store', error: error, trace: stack);
      if (isClosed) return;
      // Leaves _opened false, so the next visit tries again.
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  Future<void> refresh() async {
    final areas = await _tiles?.list() ?? const <OfflineArea>[];
    await _ledger?.retainOnly({for (final a in areas) a.key});
    final costs = await _ledger?.read() ?? const <String, OfflineAreaCost>{};
    final bytes = await mapStorageBytes();
    if (isClosed) return;
    emit(
      state.copyWith(
        loading: false,
        areas: areas,
        costs: costs,
        storageBytes: bytes,
      ),
    );
  }

  /// True when a download is already running, so a caller does not start a
  /// second one over it.
  bool get isDownloading => _download != null;

  Future<void> download({
    required String styleUrl,
    required GeoBounds bounds,
    required double minZoom,
    required double maxZoom,
    required String name,
    required String key,
  }) async {
    final tiles = _tiles;
    if (tiles == null || isDownloading) return;
    _downloadKey = key;
    _downloadRegionId = null;
    _lastRecorded = null;
    emit(state.copyWith(clearDownload: true, failed: false));
    _download = tiles
        .download(
          styleUrl: styleUrl,
          bounds: bounds,
          minZoom: minZoom,
          maxZoom: maxZoom,
          name: name,
          key: key,
        )
        .listen(
          (progress) {
            if (isClosed) return;
            _downloadRegionId ??= progress.regionId;
            emit(
              state.copyWith(
                download: OfflineDownload(name: name, progress: progress),
              ),
            );
            if (progress.isComplete) {
              unawaited(_finish(progress));
            } else {
              unawaited(_recordProgress(key, progress));
            }
          },
          onError: (Object error, StackTrace stack) {
            logs.severe('Offline download', error: error, trace: stack);
            if (isClosed) return;
            unawaited(_stop());
            emit(state.copyWith(clearDownload: true, failed: true));
            // A download that failed part way still wrote tiles, and the
            // region it wrote them into is on the device. Without this the
            // screen keeps saying nothing is kept, and offers no way to
            // delete what is.
            unawaited(refresh());
          },
        );
  }

  /// Writes what the running download has cost so far, at most every
  /// [_recordEvery]. Marked incomplete, so a download that never finishes
  /// is reported as the partial thing it is.
  Future<void> _recordProgress(String key, OfflineProgress progress) async {
    final now = DateTime.now();
    final last = _lastRecorded;
    if (last != null && now.difference(last) < _recordEvery) return;
    _lastRecorded = now;
    await _ledger?.record(
      key,
      OfflineAreaCost(
        tiles: progress.tilesDone,
        bytes: progress.bytes,
        // A lower bound until the renderer has finished counting, which is
        // why it is recorded on every pass rather than only the first.
        expected: progress.isEstimate ? 0 : progress.tilesTotal,
        complete: false,
      ),
    );
  }

  Future<void> _finish(OfflineProgress progress) async {
    final key = _downloadKey;
    final finishedRegion = _downloadRegionId ?? progress.regionId;
    await _stop();
    try {
      if (key != null) {
        // The only moment the size exists: no region reports it afterwards.
        await _ledger?.record(
          key,
          OfflineAreaCost(
            tiles: progress.tilesDone,
            bytes: progress.bytes,
            expected: progress.tilesTotal,
          ),
        );
        for (final id in supersededAreaIds(
          await _tiles?.list() ?? const [],
          key,
          keepId: finishedRegion,
        )) {
          await _tiles?.delete(id);
        }
      }
    } on Object catch (error, stack) {
      // Sweeping the leftovers is tidying, not the download. Letting it
      // throw here left the screen showing a finished progress bar for ever,
      // with every button disabled behind it.
      logs.warning('Offline sweep', error: error, trace: stack);
    } finally {
      if (!isClosed) {
        emit(state.copyWith(clearDownload: true));
        await refresh();
      }
    }
  }

  Future<void> _stop() async {
    final download = _download;
    _download = null;
    _downloadKey = null;
    _downloadRegionId = null;
    await download?.cancel();
  }

  void failureReported() {
    if (isClosed) return;
    emit(state.copyWith(failed: false));
  }

  /// Throws away what accumulated behind the user, keeping what they chose.
  Future<void> clearCache() async {
    await _tiles?.clearCache();
    await refresh();
  }

  /// Whether [id] is the region the running download is writing into.
  ///
  /// It appears in [list] like any other, so the screen would otherwise
  /// offer to delete it — and deleting it destroys the download without the
  /// renderer reporting anything, leaving a progress bar that never ends.
  bool isDownloadingInto(int id) =>
      _download != null && _downloadRegionId == id;

  /// Removes every region holding one area.
  ///
  /// An interrupted download leaves a region per attempt, so an area the
  /// user sees as one row can be several. Deleting one of them would leave
  /// the row in place holding the rest.
  Future<void> deleteArea(List<int> regionIds) async {
    if (regionIds.any(isDownloadingInto)) return;
    for (final id in regionIds) {
      await _tiles?.delete(id);
    }
    await refresh();
  }

  @override
  Future<void> close() async {
    // Cancelled here as well as in _stop, where the analyzer cannot see it.
    // Reaching this at all means the process is going away: nothing else
    // closes a cubit the locator owns.
    await _download?.cancel();
    await _stop();
    _tiles?.dispose();
    return super.close();
  }
}
