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
  // Measured on a Samsung SM-G970U1 (Android 12), z10-15, on two places
  // chosen for how differently they are mapped:
  //
  //   rural Quebec (48.0, -71.5)        Paris (48.86, 2.35)
  //     10 km    1,313 tiles    7.0 MB     5 km      676 tiles   27.9 MB
  //     25 km    5,585 tiles   10.7 MB    10 km    1,331 tiles   57.0 MB
  //     50 km   20,847 tiles   27.6 MB    25 km    5,887 tiles  146.2 MB
  //    100 km   81,050 tiles   86.2 MB    50 km   21,611 tiles  238.2 MB
  //    150 km  181,080 tiles  199.0 MB
  //
  // Two things follow, and the second is why the maximum is what it is.
  //
  // Radius is a poor unit of cost. At the same radius and nearly the same
  // tile count — 1,331 against 1,313 — Paris costs eight times what rural
  // Quebec does, because a tile there carries eight times the detail. A
  // figure derived from radius alone would mislead by that factor, so the
  // screen reports megabytes as they arrive instead of predicting them.
  //
  // MapLibre's 6,000-tile cap is not the ceiling. It is Mapbox heritage —
  // the Android method is `setOfflineMapboxTileCountLimit` and the C++
  // header scopes it: "This limit does not apply to non-Mapbox tile
  // sources." A single 150 km region downloaded all 181,080 of its tiles,
  // thirty times that cap, and reported complete.
  //
  // The real ceiling is a JNI leak in the renderer plugin. Every status
  // event from a running download allocates JNI references that are never
  // released: maplibre_android 0.3.5 releases them into the Arena of the
  // `using` block that `downloadRegion` returns from, which has already
  // closed by the time any callback fires. The global reference table caps
  // at 51,200 entries, and when it fills the process aborts —
  //
  //   signal 6 (SIGABRT)
  //   Abort message: 'JNI ERROR (app bug): global reference table overflow
  //   (max=51200)'  #05 art::JNI<true>::NewGlobalRef  #07 libdartjni.so
  //
  // Reproduced twice, with identical abort messages, on 200 km regions. It
  // is driven by status events and therefore by elapsed download time, not
  // by tiles: the crashes came after roughly 20 and 28 minutes of
  // cumulative downloading, while 181,080 fast tiles passed untouched.
  // maplibre 0.3.6 fixes JNI leaks in StyleController and the map query
  // methods, but not this path.
  //
  // Hence 50 km: the slowest measured download at that radius took 160
  // seconds, an order of magnitude below where the abort has ever been
  // seen. The slider is not capped by the renderer, it is capped by the
  // plugin bug it has to survive. Raise it when that is fixed upstream.
  static const _minZoom = 10.0;
  static const _maxZoom = 15.0;

  /// Bounded by the plugin's JNI leak, not by the renderer — see above.
  static const _maxRadiusKm = 50.0;

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
                          max: _maxRadiusKm,
                          divisions: _maxRadiusKm.round() - 1,
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
