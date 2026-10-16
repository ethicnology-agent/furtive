import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/offline_maps/offline_maps_cubit.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:geo/geo.dart';
import 'package:ui_kit/ui_kit.dart';

/// Choosing which map areas survive going offline.
///
/// Distinct from the ambient cache, which needs no screen: that is whatever
/// the user happened to look at and the renderer may reclaim it. This is what
/// they asked to keep, and only they can say which part of the world that is.
///
/// The screen owns none of the work. The store and any download in flight
/// belong to [OfflineMapsCubit], which the locator keeps for the life of the
/// process, so leaving this page no longer stops a download that is running.
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

  /// The slider moves in tens. The measurements above are what makes a finer
  /// step pointless: between 10 and 20 km a rural download grows by a couple
  /// of megabytes, and a dense one by tens — neither is a quantity a user
  /// picks to the kilometre, and offering 50 stops implied a precision the
  /// cost does not have.
  static const _stepKm = 10.0;

  /// The only thing this screen still owns: where the slider is. Everything
  /// else outlives it.
  double _radiusKm = 10;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<OfflineMapsCubit>().open());
  }

  /// ui_kit's helper resolves the messenger from a BuildContext, which is the
  /// one thing that must not be touched across the awaits below. Same
  /// behaviour — replace what is on screen rather than queue behind it — from
  /// a messenger captured before the first gap.
  static void _show(ScaffoldMessengerState messenger, SnackBar bar) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(bar);

  static String _megabytes(int bytes) =>
      (bytes / 1024 / 1024).toStringAsFixed(1);

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<OfflineMapsCubit>();
    final centre = widget.currentPosition();
    if (centre == null) {
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

    // What was asked for, rounded so that asking again produces the same
    // string. Asking again is the only way to finish an interrupted
    // download — the renderer has no resume, it starts a second region that
    // reuses the tiles the first one already stored — and this is what lets
    // the leftover be recognised afterwards.
    final key =
        '${centre.latitude.toStringAsFixed(3)},'
        '${centre.longitude.toStringAsFixed(3)}'
        '@${_radiusKm.round()}/$_minZoom-$_maxZoom';

    await cubit.download(
      styleUrl: style,
      bounds: bounds,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      name: '${_radiusKm.round()} km',
      key: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<OfflineMapsCubit, OfflineMapsState>(
      listenWhen: (previous, current) => previous.failed != current.failed,
      listener: (context, state) {
        if (!state.failed) return;
        _show(
          ScaffoldMessenger.of(context),
          SnackBar(
            content: Text(l10n.offlineFailed),
            backgroundColor: AppColors.destructive.background,
          ),
        );
        context.read<OfflineMapsCubit>().failureReported();
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(l10n.offlineTitle)),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : !state.supported
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                          // Hidden while a download runs rather than
                          // disabled. The download outlives this screen, so
                          // coming back builds a fresh slider at the default,
                          // which would sit reading 10 km under the progress
                          // bar of a 50 km download.
                          if (state.progress == null) ...[
                            Text(
                              l10n.offlineRadius(_radiusKm.round().toString()),
                            ),
                            Slider(
                              value: _radiusKm,
                              min: _stepKm,
                              max: _maxRadiusKm,
                              divisions: (_maxRadiusKm / _stepKm).round() - 1,
                              onChanged: (value) =>
                                  setState(() => _radiusKm = value),
                            ),
                          ],
                          if (state.progress case final progress?) ...[
                            LinearProgressIndicator(value: progress.fraction),
                            const SizedBox(height: 8),
                            Text(
                              l10n.offlineDownloading(
                                progress.tilesDone.toString(),
                                progress.tilesTotal.toString(),
                                _megabytes(progress.bytes),
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
                  if (state.storageBytes case final bytes?) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.offlineStorageTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.offlineStorageOnDevice(_megabytes(bytes)),
                            ),
                            Text(
                              l10n.offlineStorageKept(
                                _megabytes(state.keptBytes),
                                state.keptTiles.toString(),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.offlineStorageCached,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: kTextMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.areas.isEmpty)
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
                          for (final area in state.areas)
                            ListTile(
                              leading: const Icon(Icons.map_outlined),
                              title: Text(
                                area.name.isEmpty ? '#${area.id}' : area.name,
                              ),
                              trailing: IconButton(
                                tooltip: l10n.offlineDelete,
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => context
                                    .read<OfflineMapsCubit>()
                                    .delete(area.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
