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

  const ActivityStatsWidget({
    super.key,
    required this.activity,
    required this.elapsedTime,
    this.opaqueBackground = false,
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
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.statsElapsed,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            widget.elapsedTime.toHHMMSS(),
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(color: kMint),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              StatBlock(
                icon: Icons.timer_outlined,
                label: l10n.statDuration,
                value:
                    (_paused
                            ? activity.pausedDuration
                            : activity.activeDuration)
                        .toHHMMSS(),
              ),
              StatBlock(
                icon: Icons.straighten_rounded,
                label: l10n.statDistance,
                value:
                    '${(_paused ? activity.pausedDistanceInKm : activity.activeDistanceInKm).fmt2} km',
                emphasize: true,
              ),
              StatBlock(
                icon: Icons.timelapse_rounded,
                label: l10n.statPace,
                value:
                    '${_paused ? activity.pausedPaceMinPerKm : activity.activePaceMinPerKm} /km',
              ),
              StatBlock(
                icon: Icons.speed_rounded,
                label: l10n.statSpeed,
                value:
                    '${(_paused ? activity.pausedSpeedKmh : activity.activeSpeedKmh).fmt2} km/h',
              ),
              if (!_paused)
                StatBlock(
                  icon: Icons.terrain_rounded,
                  label: l10n.statElevation,
                  value: '${activity.activeElevationGain.round()} m',
                ),
            ],
          ),
        ],
      ),
    );
    return widget.opaqueBackground
        ? ColoredBox(color: Colors.black, child: content)
        : content;
  }
}
