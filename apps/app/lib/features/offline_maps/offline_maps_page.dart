import 'dart:async';

import 'package:flutter/material.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:geo/geo.dart';
import 'package:map_view/map_view.dart';
import 'package:ui_kit/ui_kit.dart';

/// Choosing which map areas survive going offline.
///
/// Distinct from the ambient cache, which needs no screen: that is whatever
/// the user happened to look at and the renderer may reclaim it. This is what
/// they asked to keep, and only they can say which part of the world that is.
class OfflineMapsPage extends StatefulWidget {
  const OfflineMapsPage({
    super.key,
    required this.styleUrl,
    required this.currentPosition,
  });

  /// The style to download, or null when the build has no tiles at all.
  /// Resolved by the caller: which style to keep depends on theme, language
  /// and the tile opt-out, none of which is this page's business.
  final Future<String?> Function() styleUrl;

  /// Where the user is now, or null before a fix has arrived. A download is
  /// centred on it, so there is nothing to offer until it exists.
  final PositionEntity? Function() currentPosition;

  @override
  State<OfflineMapsPage> createState() => _OfflineMapsPageState();
}

class _OfflineMapsPageState extends State<OfflineMapsPage> {
  // Measured on an Android 12 device over rural Quebec, z10-15:
  //
  //      5 km     636 tiles    6.4 MB   10.1 KB/tile
  //     10 km   1,213 tiles    8.2 MB    6.8 KB/tile
  //     25 km   5,109 tiles   19.2 MB    3.8 KB/tile
  //
  // Tiles get cheaper as the area grows, because the ones further out are
  // emptier. The slider's 25 km maximum is 5,109 tiles — just under
  // MapLibre's 6,000 cap, which is what makes raising that cap worth doing
  // rather than theoretical: a second area of that size would cross it.
  //
  // An earlier note here reasoned that tile count quadruples per zoom level
  // and concluded a 10 km radius would be hundreds of megabytes. That is
  // true of a full pyramid and false of a real vector tileset: most tiles at
  // street zoom are empty and are never fetched, so doubling the radius cost
  // under two megabytes rather than twenty-five times the download.
  //
  // The figures are one rural location and do not generalise: a dense city
  // carries far more per tile.
  //
  // MapLibre's 6,000-tile cap is not among the limits here. It is Mapbox
  // heritage — the Android method is `setOfflineMapboxTileCountLimit` and
  // the C++ header scopes it: "This limit does not apply to non-Mapbox tile
  // sources." Measured rather than taken on faith: with the cap set to 100,
  // a region needing 636 tiles downloaded all 636 and reported complete.
  // Nothing here raises it, because nothing here is bound by it.
  static const _minZoom = 10.0;
  static const _maxZoom = 15.0;

  OfflineTiles? _tiles;
  List<OfflineArea> _areas = const [];
  double _radiusKm = 10;
  OfflineProgress? _progress;
  StreamSubscription<OfflineProgress>? _download;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    if (!OfflineTiles.isSupported) {
      setState(() => _loading = false);
      return;
    }
    final tiles = await OfflineTiles.create();
    if (!mounted) {
      tiles.dispose();
      return;
    }
    _tiles = tiles;
    await _refresh();
  }

  Future<void> _refresh() async {
    final areas = await _tiles?.list() ?? const <OfflineArea>[];
    if (!mounted) return;
    setState(() {
      _areas = areas;
      _loading = false;
    });
  }

  @override
  void dispose() {
    unawaited(_download?.cancel());
    _tiles?.dispose();
    super.dispose();
  }

  /// ui_kit's helper resolves the messenger from a BuildContext, which is the
  /// one thing that must not be touched across the awaits below. Same
  /// behaviour — replace what is on screen rather than queue behind it — from
  /// a messenger captured before the first gap.
  static void _show(ScaffoldMessengerState messenger, SnackBar bar) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(bar);

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tiles = _tiles;
    final centre = widget.currentPosition();
    if (tiles == null || centre == null) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoPosition)));
      return;
    }
    final style = await widget.styleUrl();
    if (!mounted) return;
    if (style == null) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoTiles)));
      return;
    }
    final bounds = boundsAround(centre, _radiusKm * 1000);
    if (bounds == null || bounds.isEmpty) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoPosition)));
      return;
    }

    setState(() => _progress = null);
    _download = tiles
        .download(
          styleUrl: style,
          bounds: bounds,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          name: '${_radiusKm.round()} km',
        )
        .listen(
          (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
            if (progress.isComplete) {
              setState(() => _progress = null);
              unawaited(_refresh());
            }
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _progress = null);
            _show(
              messenger,
              SnackBar(
                content: Text(l10n.offlineFailed),
                backgroundColor: AppColors.destructive.background,
              ),
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !OfflineTiles.isSupported
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.offlineUnsupported,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                Text(
                  l10n.offlineExplainer,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: kTextMuted),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.offlineAroundMe,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(l10n.offlineRadius(_radiusKm.round().toString())),
                        Slider(
                          value: _radiusKm,
                          min: 1,
                          max: 25,
                          divisions: 24,
                          onChanged: _progress != null
                              ? null
                              : (value) => setState(() => _radiusKm = value),
                        ),
                        if (_progress case final progress?) ...[
                          LinearProgressIndicator(value: progress.fraction),
                          const SizedBox(height: 8),
                          Text(
                            l10n.offlineDownloading(
                              progress.tilesDone.toString(),
                              progress.tilesTotal.toString(),
                              (progress.bytes / 1024 / 1024).toStringAsFixed(1),
                            ),
                          ),
                        ] else
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _start,
                              child: Text(l10n.offlineDownload),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_areas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.offlineNone,
                      style: TextStyle(color: kTextMuted),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final area in _areas)
                          ListTile(
                            leading: const Icon(Icons.map_outlined),
                            title: Text(
                              area.name.isEmpty ? '#${area.id}' : area.name,
                            ),
                            trailing: IconButton(
                              tooltip: l10n.offlineDelete,
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                await _tiles?.delete(area.id);
                                await _refresh();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
