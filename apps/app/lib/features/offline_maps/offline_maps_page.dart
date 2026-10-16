import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/offline_maps/countries.dart';
import 'package:furtive/features/offline_maps/country_picker.dart';
import 'package:furtive/features/offline_maps/kept_areas.dart';
import 'package:furtive/features/offline_maps/offline_ledger.dart';
import 'package:furtive/features/offline_maps/offline_maps_cubit.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:geo/geo.dart';
import 'package:map_view/map_view.dart';
import 'package:ui_kit/ui_kit.dart';

const _minZoom = 10.0;
const _maxZoom = 15.0;

/// Bounded by the plugin's JNI leak, not by the renderer — see the
/// measurements on [_OfflineMapsPageState].
const _maxRadiusKm = 50.0;

/// The slider moves in tens. Those measurements are what makes a finer step
/// pointless: between 10 and 20 km a rural download grows by a couple of
/// megabytes, and a dense one by tens — neither is a quantity a user picks
/// to the kilometre, and offering 50 stops implied a precision the cost does
/// not have.
const _stepKm = 10.0;

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

  /// The only things this screen still owns: where the slider is and which
  /// country is in the picker. Everything else outlives it.
  double _radiusKm = 10;
  Country? _country;

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

  /// Resolves the style and hands the request over. Shared by both cards:
  /// which rectangle is wanted is their business, everything after it is not.
  Future<void> _download({
    required GeoBounds bounds,
    required String name,
    required String what,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<OfflineMapsCubit>();
    final String? style;
    try {
      style = await widget.styleUrl();
    } on Object {
      // Resolving the style reaches the network, and a failure there is a
      // failed download like any other rather than an error nobody reports.
      if (!mounted) return;
      _show(
        messenger,
        SnackBar(
          content: Text(l10n.offlineFailed),
          backgroundColor: AppColors.destructive.background,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (style == null) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoTiles)));
      return;
    }
    if (bounds.isEmpty) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoPosition)));
      return;
    }
    await cubit.download(
      styleUrl: style,
      bounds: bounds,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
      name: name,
      // The style is part of what was asked for, not just how it is drawn.
      // Two themes, or two label languages, need different style documents,
      // sprites and glyphs — so a download in one must not be swept away by
      // the same area downloaded in the other.
      key: '$what/$_minZoom-$_maxZoom@${_styleIdentity(style)}',
    );
  }

  /// A short, stable stand-in for the style URL.
  ///
  /// The URL carries the API key, and the key goes into region metadata that
  /// this application exports in its diagnostics. A hash identifies the
  /// style just as well without writing the secret down.
  static String _styleIdentity(String styleUrl) =>
      styleUrl.hashCode.toRadixString(16);

  Future<void> _startAroundMe() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final centre = widget.currentPosition();
    if (centre == null) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoPosition)));
      return;
    }
    final bounds = boundsAround(centre, _radiusKm * 1000);
    if (bounds == null) {
      _show(messenger, SnackBar(content: Text(l10n.offlineNoPosition)));
      return;
    }
    // What was asked for, rounded so that asking again produces the same
    // string. Asking again is the only way to finish an interrupted
    // download — the renderer has no resume, it starts a second region that
    // reuses the tiles the first one already stored — and this is what lets
    // the leftover be recognised afterwards.
    final what =
        '${centre.latitude.toStringAsFixed(3)},'
        '${centre.longitude.toStringAsFixed(3)}'
        '@${_radiusKm.round()}';
    await _download(
      bounds: bounds,
      name: '${_radiusKm.round()} km',
      what: what,
    );
  }

  Future<void> _startCountry(Country country) => _download(
    bounds: country.bounds,
    name: country.name,
    // The box is fixed, so the code alone identifies the request.
    what: 'country:${country.code}',
  );

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
        body: switch (state) {
          OfflineMapsState(loading: true) => const Center(
            child: CircularProgressIndicator(),
          ),
          OfflineMapsState(supported: false) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.offlineUnsupported, textAlign: TextAlign.center),
            ),
          ),
          _ => _Body(
            state: state,
            radiusKm: _radiusKm,
            country: _country,
            onRadiusChanged: (value) => setState(() => _radiusKm = value),
            onPickCountry: () async {
              final picked = await showCountryPicker(context);
              if (picked != null && mounted) {
                setState(() => _country = picked);
              }
            },
            onDownloadAroundMe: _startAroundMe,
            onDownloadCountry: _startCountry,
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.radiusKm,
    required this.country,
    required this.onRadiusChanged,
    required this.onPickCountry,
    required this.onDownloadAroundMe,
    required this.onDownloadCountry,
  });

  final OfflineMapsState state;
  final double radiusKm;
  final Country? country;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onPickCountry;
  final VoidCallback onDownloadAroundMe;
  final ValueChanged<Country> onDownloadCountry;

  /// Nothing may be asked for while something is being fetched: the store
  /// runs one download at a time.
  bool get _idle => state.download == null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(
          l10n.offlineExplainer,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: kTextMuted),
        ),
        const SizedBox(height: 16),
        // The download belongs to neither card below: only one runs at a
        // time, it outlives this screen, and it can have been started by
        // either. Showing it inside the radius card labelled a country
        // download "keep the area around me".
        if (state.download case final download?) ...[
          _DownloadCard(download: download),
          const SizedBox(height: 16),
        ],
        _AroundMeCard(
          radiusKm: radiusKm,
          enabled: _idle,
          onChanged: onRadiusChanged,
          onDownload: onDownloadAroundMe,
        ),
        const SizedBox(height: 16),
        _CountryCard(
          country: country,
          enabled: _idle,
          onPick: onPickCountry,
          onDownload: onDownloadCountry,
        ),
        const SizedBox(height: 16),
        if (state.storageBytes case final bytes?) ...[
          _StorageCard(bytes: bytes, state: state, canClear: _idle),
          const SizedBox(height: 16),
        ],
        _KeptAreas(state: state),
      ],
    );
  }
}

/// The chrome every section on this screen shares.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          ...children,
        ],
      ),
    ),
  );
}

/// Muted explanatory text, as every section uses it.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kTextMuted),
  );
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.download});

  final OfflineDownload download;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final progress = download.progress;
    return _Section(
      title: download.name,
      children: [
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.fraction),
        const SizedBox(height: 8),
        Text(
          l10n.offlineDownloading(
            progress.tilesDone.toString(),
            progress.tilesTotal.toString(),
            _megabytes(progress.bytes),
          ),
        ),
      ],
    );
  }
}

class _AroundMeCard extends StatelessWidget {
  const _AroundMeCard({
    required this.radiusKm,
    required this.enabled,
    required this.onChanged,
    required this.onDownload,
  });

  final double radiusKm;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Section(
      title: l10n.offlineAroundMe,
      children: [
        Text(l10n.offlineRadius(radiusKm.round().toString())),
        Slider(
          value: radiusKm,
          min: _stepKm,
          max: _maxRadiusKm,
          divisions: (_maxRadiusKm / _stepKm).round() - 1,
          onChanged: enabled ? onChanged : null,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: enabled ? onDownload : null,
            child: Text(l10n.offlineDownload),
          ),
        ),
      ],
    );
  }
}

class _CountryCard extends StatelessWidget {
  const _CountryCard({
    required this.country,
    required this.enabled,
    required this.onPick,
    required this.onDownload,
  });

  final Country? country;
  final bool enabled;
  final VoidCallback onPick;
  final ValueChanged<Country> onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chosen = country;
    return _Section(
      title: l10n.offlineCountry,
      children: [
        _Note(l10n.offlineCountryBox),
        const SizedBox(height: 8),
        if (chosen != null) ...[
          Text(chosen.name),
          // Exact, not an estimate — the count is geometry. Bytes are not
          // shown because they cannot be predicted: the same tile measured
          // 1.1 KB over open country and 11 KB over Paris.
          _Note(
            l10n.offlineCountryTiles(
              tilesForDownload(
                bounds: chosen.bounds,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
              ).toString(),
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: enabled ? onPick : null,
              child: Text(l10n.offlineCountryPick),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: enabled && chosen != null
                  ? () => onDownload(chosen)
                  : null,
              child: Text(l10n.offlineDownload),
            ),
          ],
        ),
      ],
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.bytes,
    required this.state,
    required this.canClear,
  });

  final int bytes;
  final OfflineMapsState state;
  final bool canClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Section(
      title: l10n.offlineStorageTitle,
      children: [
        const SizedBox(height: 4),
        Text(l10n.offlineStorageOnDevice(_megabytes(bytes))),
        Text(
          l10n.offlineStorageKept(
            _megabytes(state.keptBytes),
            state.keptTiles.toString(),
          ),
        ),
        const SizedBox(height: 4),
        _Note(l10n.offlineStorageCached),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            // Only what accumulated behind them: the areas they asked for
            // are not evictable and are not touched.
            onPressed: canClear
                ? () => context.read<OfflineMapsCubit>().clearCache()
                : null,
            child: Text(l10n.offlineClearCache),
          ),
        ),
      ],
    );
  }
}

class _KeptAreas extends StatelessWidget {
  const _KeptAreas({required this.state});

  final OfflineMapsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.areas.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.offlineNone, style: TextStyle(color: kTextMuted)),
      );
    }
    final cubit = context.read<OfflineMapsCubit>();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Grouped, because a download that was interrupted and asked for
          // again is held in several regions: listing those showed the same
          // area twice, each row repeating its one recorded cost.
          for (final area in keptAreas(state.areas))
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(
                area.name.isEmpty ? '#${area.regionIds.first}' : area.name,
              ),
              subtitle: _cost(l10n, state.costs[area.key]),
              // The running download's region is listed like any other, and
              // deleting it destroys the download without the renderer
              // saying so — leaving a progress bar that never ends.
              trailing: IconButton(
                tooltip: l10n.offlineDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: area.regionIds.any(cubit.isDownloadingInto)
                    ? null
                    : () => cubit.deleteArea(area.regionIds),
              ),
            ),
        ],
      ),
    );
  }

  /// Null for an area kept by a build that wrote no record. Showing nothing
  /// is right; showing 0.0 MB would be a measurement.
  Widget? _cost(AppLocalizations l10n, OfflineAreaCost? cost) {
    if (cost == null) return null;
    final mb = _megabytes(cost.bytes);
    final tiles = cost.tiles.toString();
    return Text(
      cost.complete
          ? l10n.offlineAreaCost(mb, tiles)
          // Asking for it again finishes it from the tiles already stored.
          : l10n.offlineAreaCostPartial(mb, tiles),
    );
  }
}

String _megabytes(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);
