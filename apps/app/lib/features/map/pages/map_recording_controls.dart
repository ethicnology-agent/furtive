import 'package:flutter/material.dart';
import 'package:furtive/core/entities/activity_profile.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/core/widgets/activity_type_picker.dart';
import 'package:furtive/core/widgets/hold_to_confirm_button.dart';
import 'package:furtive/l10n/app_localizations.dart';

/// Keeps the recording action under the same thumb across state transitions.
class MapRecordingControls extends StatelessWidget {
  const MapRecordingControls({
    super.key,
    required this.isRecording,
    required this.isPaused,
    required this.isStarting,
    required this.isFollowing,
    required this.hasLocation,
    required this.activityType,
    required this.onFollow,
    required this.onStart,
    required this.onPause,
    required this.onStop,
    required this.onPickType,
    this.shareControl,
  });

  final bool isRecording;
  final bool isPaused;
  final bool isStarting;
  final bool isFollowing;
  final bool hasLocation;
  final ActivityTypeEntity activityType;
  final VoidCallback onFollow;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onPickType;
  final Widget? shareControl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stopButton = HoldToConfirmButton(
      icon: Icons.stop_rounded,
      label: l10n.btnStop,
      shortTapHint: l10n.mapStopHint,
      progressLabel: l10n.mapHoldStopProgress,
      backgroundColor: AppColors.destructive.background,
      foregroundColor: AppColors.destructive.foreground,
      onConfirmed: onStop,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 32,
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isRecording) ...[stopButton, const SizedBox(height: 16)],
            Semantics(
              selected: hasLocation && isFollowing,
              child: FloatingActionButton.extended(
                heroTag: 'follow',
                onPressed: hasLocation ? onFollow : null,
                backgroundColor: isFollowing
                    ? AppColors.secondary.background
                    : null,
                foregroundColor: isFollowing
                    ? AppColors.secondary.foreground
                    : null,
                label: Text(
                  !hasLocation
                      ? l10n.mapWaitingForLocation
                      : isFollowing
                      ? l10n.mapFollowing
                      : l10n.btnFollow,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(Icons.my_location_rounded),
              ),
            ),
            if (!isRecording) ...[
              const SizedBox(height: 16),
              FloatingActionButton.extended(
                heroTag: 'activity-type',
                backgroundColor: AppColors.tertiary.background,
                foregroundColor: AppColors.tertiary.foreground,
                onPressed: isStarting ? null : onPickType,
                icon: Icon(activityTypeIcon(activityType)),
                label: Text(
                  activityTypeName(l10n, activityType),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (shareControl != null) ...[
              const SizedBox(height: 16),
              shareControl!,
            ],
            const SizedBox(height: 16),
            FloatingActionButton.extended(
              key: const ValueKey('recording-primary'),
              heroTag: 'recording-primary',
              onPressed: isStarting
                  ? null
                  : isRecording
                  ? onPause
                  : onStart,
              backgroundColor: AppColors.primary.background,
              label: Text(
                isStarting
                    ? l10n.btnStarting
                    : isRecording
                    ? isPaused
                          ? l10n.btnResume
                          : l10n.btnPause
                    : l10n.btnStart,
                overflow: TextOverflow.ellipsis,
              ),
              icon: isStarting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isRecording && !isPaused
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
