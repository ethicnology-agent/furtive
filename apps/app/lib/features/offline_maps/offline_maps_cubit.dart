import 'dart:async';

import 'package:diagnostics/diagnostics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/offline_maps/map_storage.dart';
import 'package:furtive/features/offline_maps/offline_ledger.dart';
import 'package:furtive/features/offline_maps/superseded_areas.dart';
import 'package:geo/geo.dart';
import 'package:map_view/map_view.dart';

/// What the offline maps screen shows, and the download it is watching.
class OfflineMapsState {
  const OfflineMapsState({
    this.loading = true,
    this.supported = true,
    this.areas = const [],
    this.costs = const {},
    this.storageBytes,
    this.progress,
    this.downloadName = '',
    this.failed = false,
  });

  final bool loading;
  final bool supported;
  final List<OfflineArea> areas;
  final Map<String, OfflineAreaCost> costs;
  final int? storageBytes;

  /// The download in flight, or null when none is.
  final OfflineProgress? progress;

  /// What that download is of, as the user asked for it — "10 km" or
  /// "France". Carried in the state because only one download runs at a
  /// time and the screen has to say which one it is showing.
  final String downloadName;

  /// Raised once when a download fails, cleared by whoever reported it.
  final bool failed;

  OfflineMapsState copyWith({
    bool? loading,
    bool? supported,
    List<OfflineArea>? areas,
    Map<String, OfflineAreaCost>? costs,
    int? storageBytes,
    OfflineProgress? progress,
    bool clearProgress = false,
    String? downloadName,
    bool? failed,
  }) => OfflineMapsState(
    loading: loading ?? this.loading,
    supported: supported ?? this.supported,
    areas: areas ?? this.areas,
    costs: costs ?? this.costs,
    storageBytes: storageBytes ?? this.storageBytes,
    progress: clearProgress ? null : progress ?? this.progress,
    downloadName: clearProgress ? '' : downloadName ?? this.downloadName,
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

  bool _opened = false;

  /// Prepares the store. Safe to call on every visit to the screen; the work
  /// happens once, and a download already running is left alone.
  Future<void> open() async {
    if (_opened) {
      await refresh();
      return;
    }
    _opened = true;
    if (!OfflineTiles.isSupported) {
      emit(state.copyWith(loading: false, supported: false));
      return;
    }
    final tiles = await OfflineTiles.create();
    _tiles = tiles;
    // Also set at startup; repeated here so this screen works even if that
    // pass failed.
    unawaited(tiles.setMaximumCacheSize(ambientCacheBudgetBytes));
    _ledger = OfflineLedger(await offlineLedgerFile());
    await refresh();
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
    emit(state.copyWith(clearProgress: true, failed: false));
    emit(state.copyWith(downloadName: name));
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
            emit(state.copyWith(progress: progress));
            if (progress.isComplete) unawaited(_finish(progress));
          },
          onError: (Object error, StackTrace stack) {
            logs.severe('Offline download', error: error, trace: stack);
            if (isClosed) return;
            unawaited(_stop());
            emit(state.copyWith(clearProgress: true, failed: true));
          },
        );
  }

  Future<void> _finish(OfflineProgress progress) async {
    final key = _downloadKey;
    await _stop();
    if (key != null) {
      // The only moment the size exists: no region reports it afterwards.
      await _ledger?.record(
        key,
        OfflineAreaCost(tiles: progress.tilesDone, bytes: progress.bytes),
      );
      for (final id in supersededAreaIds(
        await _tiles?.list() ?? const [],
        key,
      )) {
        await _tiles?.delete(id);
      }
    }
    if (isClosed) return;
    emit(state.copyWith(clearProgress: true));
    await refresh();
  }

  Future<void> _stop() async {
    final download = _download;
    _download = null;
    _downloadKey = null;
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

  Future<void> delete(int id) async {
    await _tiles?.delete(id);
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
