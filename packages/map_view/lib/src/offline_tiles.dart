import 'package:geo/geo.dart';
import 'package:maplibre/maplibre.dart' as ml;

/// An area the user chose to keep, and how much of it is on the device.
class OfflineArea {
  const OfflineArea({required this.id, required this.name});

  final int id;

  /// What the user called it, or empty when the metadata carries no name —
  /// a region downloaded by an older build, or by something else.
  final String name;
}

/// Progress of one download, as the renderer reports it.
class OfflineProgress {
  const OfflineProgress({
    required this.tilesDone,
    required this.tilesTotal,
    required this.bytes,
    required this.isEstimate,
    required this.isComplete,
  });

  final int tilesDone;

  /// A lower bound until [isEstimate] goes false: the renderer cannot count
  /// the tiles until it has fetched the style and the sources.
  final int tilesTotal;
  final int bytes;
  final bool isEstimate;
  final bool isComplete;

  /// Null while the total is still a guess, so a caller shows an
  /// indeterminate bar rather than one that jumps backwards.
  double? get fraction =>
      isEstimate || tilesTotal <= 0 ? null : tilesDone / tilesTotal;
}

/// The renderer's own store of tiles kept for offline use.
///
/// A port rather than direct use of the renderer, for the same reason
/// [MapView] is one: the tile store belongs to whatever draws the map, and
/// naming it here is what keeps that choice swappable. Callers speak
/// [GeoBounds] and a style URL; neither mentions MapLibre.
///
/// Distinct from the ambient cache, which needs no API at all: that is
/// whatever the user happened to look at, and the renderer evicts it. This
/// is what they asked to keep.
abstract interface class OfflineTiles {
  /// Whether the platform has an offline store. False on web.
  static bool get isSupported => ml.OfflineManager.isSupported;

  static Future<OfflineTiles> create() async =>
      _MapLibreOfflineTiles(await ml.OfflineManager.createInstance());

  /// Downloads everything needed to draw [bounds] between the two zooms.
  ///
  /// [styleUrl] is passed in rather than resolved here: which style to keep
  /// is the application's decision, and this module has no business knowing
  /// about themes, languages or API keys.
  Stream<OfflineProgress> download({
    required String styleUrl,
    required GeoBounds bounds,
    required double minZoom,
    required double maxZoom,
    required String name,
  });

  Future<List<OfflineArea>> list();

  Future<void> delete(int id);

  /// Caps the evictable cache — the tiles nobody asked to keep. Downloaded
  /// areas are not evicted and are not counted against this.
  Future<void> setMaximumCacheSize(int bytes);

  void dispose();
}

class _MapLibreOfflineTiles implements OfflineTiles {
  _MapLibreOfflineTiles(this._manager);

  final ml.OfflineManager _manager;

  static const _nameKey = 'furtive.name';

  @override
  Stream<OfflineProgress> download({
    required String styleUrl,
    required GeoBounds bounds,
    required double minZoom,
    required double maxZoom,
    required String name,
  }) => _manager
      .downloadRegion(
        mapStyleUrl: styleUrl,
        bounds: ml.LngLatBounds(
          longitudeWest: bounds.west,
          longitudeEast: bounds.east,
          latitudeSouth: bounds.south,
          latitudeNorth: bounds.north,
        ),
        minZoom: minZoom,
        maxZoom: maxZoom,
        // 1.0 rather than the device ratio: tiles are vector, so the pixel
        // density only scales the renderer's estimate of how many it needs.
        // Asking for the device's ratio multiplies the download for no extra
        // detail on a vector basemap.
        pixelDensity: 1,
        metadata: {_nameKey: name},
      )
      .map(
        (progress) => OfflineProgress(
          tilesDone: progress.loadedTiles,
          tilesTotal: progress.totalTiles,
          bytes: progress.loadedBytes,
          isEstimate: progress.totalTilesEstimated,
          isComplete: progress.downloadCompleted,
        ),
      );

  @override
  Future<List<OfflineArea>> list() async {
    final regions = await _manager.listOfflineRegions();
    return [
      for (final region in regions)
        OfflineArea(
          id: region.id,
          name: switch (region.metadata[_nameKey]) {
            final String name => name,
            _ => '',
          },
        ),
    ];
  }

  @override
  Future<void> delete(int id) => _manager.deleteRegion(regionId: id);

  @override
  Future<void> setMaximumCacheSize(int bytes) =>
      _manager.setMaximumAmbientCacheSize(bytes: bytes);

  @override
  void dispose() => _manager.dispose();
}
