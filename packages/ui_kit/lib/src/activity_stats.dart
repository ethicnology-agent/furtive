import 'package:flutter/material.dart';

import 'formatting.dart';
import 'stat_block.dart';
import 'theme.dart';

/// One set of figures for the stats panel, already reduced to what it shows.
///
/// [pace] arrives formatted because minutes-per-kilometre is not a plain
/// number — whoever computes it decides how it reads.
class UiActivityStats {
  const UiActivityStats({
    required this.duration,
    required this.distanceKm,
    required this.pace,
    required this.speedKmh,
  });

  final Duration duration;
  final double distanceKm;
  final String pace;
  final double speedKmh;
}

/// The eight strings the panel renders, already translated.
class UiActivityStatsLabels {
  const UiActivityStatsLabels({
    required this.elapsed,
    required this.active,
    required this.paused,
    required this.duration,
    required this.distance,
    required this.pace,
    required this.speed,
    required this.elevation,
  });

  final String elapsed;
  final String active;
  final String paused;
  final String duration;
  final String distance;
  final String pace;
  final String speed;
  final String elevation;
}

/// Elapsed time over a grid of figures, with an active/paused selector once
/// a recording has been paused at least once.
///
/// Takes figures rather than a recording: the panel is shown by two
/// different journeys, so it sits below both, and a ui module may not reach
/// a business one. Elevation is reported for the active figures only —
/// elevation gained while paused is not gain anyone climbed.
class ActivityStatsWidget extends StatefulWidget {
  const ActivityStatsWidget({
    super.key,
    required this.active,
    required this.paused,
    required this.activeElevationGainMeters,
    required this.elapsedTime,
    required this.labels,
    this.hasPausedSegments = false,
    this.isCurrentlyPaused = false,
    this.opaqueBackground = false,
  });

  final UiActivityStats active;
  final UiActivityStats paused;
  final double activeElevationGainMeters;
  final Duration elapsedTime;
  final UiActivityStatsLabels labels;

  /// Whether the recording has ever been paused. The selector appears on
  /// either this or [isCurrentlyPaused]: a pause that has just begun has
  /// produced no paused segment yet, and the selector still belongs there.
  final bool hasPausedSegments;
  final bool isCurrentlyPaused;
  final bool opaqueBackground;

  @override
  State<ActivityStatsWidget> createState() => _ActivityStatsWidgetState();
}

class _ActivityStatsWidgetState extends State<ActivityStatsWidget> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels;
    final showPauseSelector =
        widget.isCurrentlyPaused || widget.hasPausedSegments;
    final showingPaused = showPauseSelector && _paused;
    final shown = showingPaused ? widget.paused : widget.active;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  labels.elapsed,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              Text(
                widget.elapsedTime.toHHMMSS(),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: kMint,
                  fontSize: 32,
                  height: 1,
                ),
              ),
            ],
          ),
          if (showPauseSelector) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(labels.active),
                  selected: !_paused,
                  onSelected: (_) => setState(() => _paused = false),
                ),
                ChoiceChip(
                  label: Text(labels.paused),
                  selected: _paused,
                  onSelected: (_) => setState(() => _paused = true),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _StatsRow(
            first: StatBlock(
              icon: Icons.timer_outlined,
              label: labels.duration,
              value: shown.duration.toHHMMSS(),
              dense: true,
            ),
            second: StatBlock(
              icon: Icons.straighten_rounded,
              label: labels.distance,
              value: '${shown.distanceKm.fmt2} km',
              emphasize: true,
              dense: true,
            ),
          ),
          const SizedBox(height: 12),
          _StatsRow(
            first: StatBlock(
              icon: Icons.timelapse_rounded,
              label: labels.pace,
              value: '${shown.pace} /km',
              dense: true,
            ),
            second: StatBlock(
              icon: Icons.speed_rounded,
              label: labels.speed,
              value: '${shown.speedKmh.fmt2} km/h',
              dense: true,
            ),
          ),
          if (!showingPaused) ...[
            const SizedBox(height: 12),
            _StatsRow(
              first: StatBlock(
                icon: Icons.terrain_rounded,
                label: labels.elevation,
                value: '${widget.activeElevationGainMeters.round()} m',
                dense: true,
              ),
            ),
          ],
        ],
      ),
    );
    return widget.opaqueBackground
        ? ColoredBox(color: Colors.black, child: content)
        : content;
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.first, this.second});

  final Widget first;
  final Widget? second;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: 16),
      Expanded(child: second ?? const SizedBox.shrink()),
    ],
  );
}
