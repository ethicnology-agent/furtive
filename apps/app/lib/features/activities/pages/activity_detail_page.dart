import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/views/map_camera.dart';
import 'package:furtive/labels/activity_stats_labels.dart';
import 'package:furtive/views/activity_stats_view.dart';
import 'package:platform_services/platform_services.dart';
import 'package:furtive/views/map_track_view.dart';
import 'package:map_view/map_view.dart';
import 'package:furtive/features/activities/widgets/km_splits_chart.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:activities/activities.dart';
import 'package:basemap/basemap.dart';
import 'package:furtive/features/activities/export_activity_to_gpx_use_case.dart';
import 'package:furtive/features/activities/share_activity_use_case.dart';
import 'package:furtive/features/activities/bloc/activities_bloc.dart';
import 'package:furtive/features/activities/bloc/activities_event.dart';
import 'package:geo/geo.dart';
import 'package:preferences/preferences.dart';
import 'package:ui_kit/ui_kit.dart';

/// What the activity menu can do. Share stays an icon; these three are
/// management, which is what an overflow menu is for.
enum _ActivityAction { rename, export, delete }

class ActivityDetailPage extends StatefulWidget {
  final ActivityEntity activity;

  const ActivityDetailPage({
    super.key,
    required this.activity,
    this.mapView,
    this.loadMapStyle,
    this.loadMilestoneInterval,
    this.exportActivity,
    this.shareActivity,
  });

  final MapView? mapView;
  final Future<String?> Function()? loadMapStyle;
  final Future<int> Function()? loadMilestoneInterval;
  final Future<void> Function(String)? exportActivity;
  final Future<void> Function(BuildContext, ActivityEntity)? shareActivity;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

// Fallback when an activity has zero usable points (Place de la Concorde,
// Paris). Picked arbitrarily — the map only renders without points if the
// user ceased before any GPS fix arrived.
final _kFallbackCenter = PositionEntity(
  latitude: 48.8566,
  longitude: 2.3522,
  elevation: 0,
);

/// First point with finite coordinates. Not `points.first`: a junk GPS fix can
/// carry NaN, which poisons the camera so that every later gesture throws.
PositionEntity _initialCenter(ActivityEntity activity) {
  for (final point in activity.points) {
    final lat = point.position.latitude;
    final lon = point.position.longitude;
    if (lat.isFinite && lon.isFinite) return point.position;
  }
  return _kFallbackCenter;
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  late final MapView _mapView = widget.mapView ?? MapLibreMapView();
  late final _getMapStyleUrlUseCase =
      widget.loadMapStyle ?? GetMapStyleUrlUseCase().call;
  late final _loadMilestoneInterval =
      widget.loadMilestoneInterval ??
      () async =>
          (await PreferencesRepository().fetch()).mapMilestoneIntervalKm;
  late final _exportActivityToGpxUseCase =
      widget.exportActivity ?? ExportActivityToGpxUseCase().call;
  late final _shareActivityUseCase =
      widget.shareActivity ?? ShareActivityUseCase().call;
  String? _mapStyleUrl;
  int _mapMilestoneIntervalKm = 1;
  // _isMapStyleLoading covers ONLY the initial map-tile-style fetch.
  // Previously _isLoading was overloaded with export-in-progress as well,
  // which meant the whole map view collapsed to a spinner during GPX
  // export and that share/export were blocked while the map style was
  // still loading even though neither needs it.
  bool _isMapStyleLoading = true;
  bool _isExporting = false;
  bool _isSharing = false;
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.activity.name;
    _loadMapStyle();
  }

  @override
  void dispose() {
    unawaited(_mapView.dispose());
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    String? styleUrl;
    var milestoneIntervalKm = 1;
    try {
      styleUrl = await _getMapStyleUrlUseCase();
    } catch (_) {}
    try {
      final storedInterval = await _loadMilestoneInterval();
      if (mapMilestoneIntervalOptionsKm.contains(storedInterval)) {
        milestoneIntervalKm = storedInterval;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _mapStyleUrl = styleUrl;
      _mapMilestoneIntervalKm = milestoneIntervalKm;
      _isMapStyleLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Un-renamed activities carry the English sentinel 'Track' — swap for
    // the localised display copy so RU/UK/FR users don't see English in
    // the AppBar.
    final l10n = AppLocalizations.of(context);
    final displayName = _currentName == kDefaultActivityName
        ? l10n.activityDefaultName
        : _currentName;
    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        // One icon and a menu, not four icons. An AppBar gives the title
        // whatever the actions leave, and four of them left about 110dp on a
        // 360dp screen: a renamed activity read "Sorti…". Measured on a
        // 411dp Pixel the same name fits at the system font size and is cut
        // to "Sortie du …" one notch up the accessibility slider, so the
        // squeeze is not a small-phone problem — it is four actions.
        actions: [
          IconButton(
            // Share + export DON'T need the map-tile style loaded — the
            // ShareCard draws its own polyline via CustomPainter and the
            // GPX export reads from the entity. Gate only on each other.
            onPressed: (_isSharing || _isExporting) ? null : _share,
            tooltip: AppLocalizations.of(context).shareTooltip,
            icon: _isSharing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  )
                : const Icon(Icons.share_rounded),
          ),
          // Export keeps its progress where it has always been — in the bar —
          // by standing in for the menu button while it runs. Hiding it in a
          // closed menu would have made a slow export look like nothing
          // happened.
          if (_isExporting)
            const IconButton(
              onPressed: null,
              icon: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
            )
          else
            PopupMenuButton<_ActivityAction>(
              // No tooltip: PopupMenuButton falls back to
              // MaterialLocalizations.showMenuTooltip, which Flutter ships
              // translated for every locale this app offers. A key of our
              // own would have been one more string to translate 26 times,
              // and worse in the locales that are behind.
              enabled: !_isSharing,
              onSelected: (action) => switch (action) {
                _ActivityAction.rename => _showRenameDialog(),
                _ActivityAction.export => _exportToGpx(),
                _ActivityAction.delete => _showDeleteDialog(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ActivityAction.rename,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(l10n.activityRenameTooltip),
                  ),
                ),
                PopupMenuItem(
                  value: _ActivityAction.export,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_download_outlined),
                    title: Text(l10n.activityExportTooltip),
                  ),
                ),
                PopupMenuItem(
                  value: _ActivityAction.delete,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: kDestructive,
                    ),
                    title: Text(
                      l10n.activityDeleteTooltip,
                      style: const TextStyle(color: kDestructive),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      // A column, not a stack. The button used to float over the map at full
      // width, and the map puts its attribution badge in a bottom corner —
      // both of them, so there was no corner left to move it to. The badge
      // ended up under the button, and ODbL 4.3 asks for credit that is
      // actually visible. Giving the button its own strip is the only
      // arrangement that cannot cover it, whatever the button's height turns
      // out to be at a large font scale.
      body: _isMapStyleLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child:
                      !widget.activity.points.any(
                        (point) =>
                            point.position.latitude.isFinite &&
                            point.position.longitude.isFinite,
                      )
                      ? Center(child: Text(l10n.activityNoTrack))
                      : Container(
                          color: AppColors.tertiary.background,
                          // Always render the map so the recorded track is visible.
                          // The tile layer is shown only when a style is available
                          // (keyed build, online); on the keyless FOSS build or an
                          // offline style fetch the polyline draws on a blank canvas
                          // instead of an error.
                          child: _mapView.build(
                            styleUrl: _mapStyleUrl,
                            track: widget.activity.asMapTrack(
                              milestoneIntervalKm: _mapMilestoneIntervalKm,
                            ),
                            fitTrackBounds: true,
                            initialCentre: _initialCenter(widget.activity),
                            initialZoom: MapCamera.maxZoom,
                            maxZoom: MapCamera.maxZoom,
                            // A finished activity: no live position to show, and asking
                            // for one would prompt for location permission on a page
                            // that has no use for it.
                            showUserLocation: false,
                            // Nothing follows the user here, so a pan means nothing.
                            onUserGesture: () {},
                          ),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(context.screenPadding),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showStatisticsBottomSheet(context, widget.activity),
                      icon: const Icon(Icons.analytics_rounded),
                      label: Text(AppLocalizations.of(context).btnViewStats),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showStatisticsBottomSheet(
    BuildContext context,
    ActivityEntity activity,
  ) {
    // B37: fall back to startedAt for activities with zero recorded points
    // (start + immediate stop before any GPS fix). Previously crashed on
    // points.last.
    final stoppedAt =
        activity.stoppedAt ??
        (activity.points.isNotEmpty
            ? activity.points.last.time
            : activity.startedAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.tertiary.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ActivityStatsWidget(
                active: activity.activeStats,
                paused: activity.pausedStats,
                activeElevationGainMeters: activity.activeElevationGain,
                hasPausedSegments: activity.pausedSegments.isNotEmpty,
                elapsedTime: stoppedAt.difference(activity.startedAt),
                labels: activityStatsLabels(AppLocalizations.of(context)),
              ),
              // Detected GPS outages (indoors, tunnel, process kill):
              // shown only when the trace actually contains one, so
              // the sheet stays clean for the common case. The time
              // is excluded from the active stats above; the
              // straight-line distance is informative only (the real
              // path through the gap is unknown).
              if (activity.signalLostDuration > Duration.zero)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.gps_off_rounded,
                        size: 18,
                        color: AppColors.secondary.background,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).statSignalLost(
                            activity.signalLostDuration.toHHMMSS(),
                            activity.signalLostDistanceMeters.round(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              KmSplitsChart(activity: activity),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportToGpx() async {
    setState(() => _isExporting = true);

    try {
      await _exportActivityToGpxUseCase(widget.activity.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).gpxExportSuccess),
          ),
        );
      }
    } on FileSaveCancelled {
      // The user backed out of the share sheet / directory picker —
      // silent no-op, not a failure (see L-G3 in docs/REVIEW-2026-07-FULL-APP.md).
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).gpxExportFailed(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      await _shareActivityUseCase(
        context,
        widget.activity.copyWith(name: _currentName),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).shareFailed(e.toString()),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _showRenameDialog() async {
    // A popped route remains mounted throughout its reverse animation.
    // Keep the controller alive until its overlay entries have been removed.
    final textController = TextEditingController(text: _currentName);
    final route = DialogRoute<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.dlgRenameTitle),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(labelText: l10n.activityNameLabel),
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actionsAlignment: MainAxisAlignment.spaceAround,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.tertiary.background,
                foregroundColor: AppColors.tertiary.foreground,
              ),
              child: Text(l10n.btnCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, textController.text.trim()),
              child: Text(l10n.btnRename),
            ),
          ],
        );
      },
    );
    try {
      final result = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);

      if (result != null && result.isNotEmpty && result != _currentName) {
        if (!mounted) return;
        final completion = Completer<void>();
        context.read<ActivitiesBloc>().add(
          UpdateActivityName(
            activityId: widget.activity.id,
            newName: result,
            completion: completion,
          ),
        );
        try {
          await completion.future;
          if (mounted) setState(() => _currentName = result);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: kDestructive,
            ),
          );
        }
      }
    } finally {
      await route.completed;
      textController.dispose();
    }
  }

  Future<void> _showDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.dlgDeleteTitle),
          content: Text(l10n.dlgDeleteConfirm),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.tertiary.background,
                foregroundColor: AppColors.tertiary.foreground,
              ),
              child: Text(l10n.btnCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive.background,
                foregroundColor: AppColors.destructive.foreground,
              ),
              child: Text(l10n.btnDelete),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      final completion = Completer<void>();
      context.read<ActivitiesBloc>().add(
        DeleteActivity(activityId: widget.activity.id, completion: completion),
      );
      try {
        await completion.future;
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final message = AppLocalizations.of(context).activityDeleteSuccess;
        Navigator.pop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: kDestructive),
        );
      }
    }
  }
}
