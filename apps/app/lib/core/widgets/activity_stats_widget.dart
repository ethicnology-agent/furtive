import 'package:flutter/material.dart';
import 'package:furtive/core/entities/activity_entity.dart';
import 'package:furtive/core/extensions.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/core/widgets/stat_block.dart';
import 'package:furtive/l10n/app_localizations.dart';

class ActivityStatsWidget extends StatefulWidget {
  final ActivityEntity activity;
  final Duration elapsedTime;
  final bool opaqueBackground;
  final bool isCurrentlyPaused;

  const ActivityStatsWidget({
    super.key,
    required this.activity,
    required this.elapsedTime,
    this.opaqueBackground = false,
    this.isCurrentlyPaused = false,
  });

  @override
  State<ActivityStatsWidget> createState() => _ActivityStatsWidgetState();
}

class _ActivityStatsWidgetState extends State<ActivityStatsWidget> {
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final activity = widget.activity;
    final showPauseSelector =
        widget.isCurrentlyPaused || activity.pausedSegments.isNotEmpty;
    final showingPaused = showPauseSelector && _paused;
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
                  l10n.statsElapsed,
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
                  label: Text(l10n.statsActive),
                  selected: !_paused,
                  onSelected: (_) => setState(() => _paused = false),
                ),
                ChoiceChip(
                  label: Text(l10n.statsPaused),
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
              label: l10n.statDuration,
              value:
                  (showingPaused
                          ? activity.pausedDuration
                          : activity.activeDuration)
                      .toHHMMSS(),
              dense: true,
            ),
            second: StatBlock(
              icon: Icons.straighten_rounded,
              label: l10n.statDistance,
              value:
                  '${(showingPaused ? activity.pausedDistanceInKm : activity.activeDistanceInKm).fmt2} km',
              emphasize: true,
              dense: true,
            ),
          ),
          const SizedBox(height: 12),
          _StatsRow(
            first: StatBlock(
              icon: Icons.timelapse_rounded,
              label: l10n.statPace,
              value:
                  '${showingPaused ? activity.pausedPaceMinPerKm : activity.activePaceMinPerKm} /km',
              dense: true,
            ),
            second: StatBlock(
              icon: Icons.speed_rounded,
              label: l10n.statSpeed,
              value:
                  '${(showingPaused ? activity.pausedSpeedKmh : activity.activeSpeedKmh).fmt2} km/h',
              dense: true,
            ),
          ),
          if (!showingPaused) ...[
            const SizedBox(height: 12),
            _StatsRow(
              first: StatBlock(
                icon: Icons.terrain_rounded,
                label: l10n.statElevation,
                value: '${activity.activeElevationGain.round()} m',
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
