import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/share/live_share_cubit.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ui_kit/ui_kit.dart';

/// The live-share control, and everything behind it.
///
/// It used to live in the map page, which is where it is shown but not what
/// it belongs to: the password dialog, the still-active prompt and the error
/// reporting are all this feature's business, and a screen that merely has
/// room for the button had no reason to own them.
///
/// Reachable whether or not a recording is running, since a share can be
/// armed in advance.
class LiveShareControl extends StatelessWidget {
  const LiveShareControl({super.key});

  /// The control, or null when this build has no sharing configured.
  ///
  /// Null rather than an empty widget because the caller's layout spaces
  /// around a control that exists; an invisible one would leave a gap.
  static Widget? maybe(BuildContext context) =>
      context.read<LiveShareCubit>().isConfigured
      ? const LiveShareControl()
      : null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<LiveShareCubit, LiveShareState>(
      listenWhen: (previous, current) =>
          previous.error != current.error && current.error != null,
      listener: (context, state) {
        showSingleSnackBar(
          context,
          SnackBar(
            content: Text(
              AppLocalizations.of(context).shareFailed(state.error!),
            ),
            backgroundColor: kDestructive,
          ),
        );
        context.read<LiveShareCubit>().clearError();
      },
      child: _fab(context, AppLocalizations.of(context)),
    );
  }

  Future<void> _shareLiveLink(
    BuildContext context,
    LiveShareCubit sharing, {
    String? password,
  }) async {
    try {
      final link =
          sharing.state.link ?? await sharing.start(password: password);
      final result = await SharePlus.instance.share(ShareParams(text: link));
      if (context.mounted &&
          result.status == ShareResultStatus.dismissed &&
          sharing.state.isActive) {
        _showShareStillActive(context, sharing);
      }
    } catch (error) {
      if (!context.mounted) return;
      if (sharing.state.isActive) {
        _showShareStillActive(context, sharing);
        return;
      }
      showSingleSnackBar(
        context,
        SnackBar(
          content: Text(AppLocalizations.of(context).shareFailed('$error')),
          backgroundColor: kDestructive,
        ),
      );
    }
  }

  void _showShareStillActive(BuildContext context, LiveShareCubit sharing) {
    final l10n = AppLocalizations.of(context);
    showSingleSnackBar(
      context,
      SnackBar(
        content: Text(l10n.liveShareStillActive),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: l10n.btnStop,
          onPressed: () => unawaited(sharing.stop()),
        ),
      ),
    );
  }

  /// Shared by both layouts: the control is reachable whether or not a
  /// recording is running, since a share can be armed in advance. Only one of
  /// the two branches is ever mounted, so the hero tag stays unique.
  Widget _fab(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<LiveShareCubit, LiveShareState>(
      builder: (context, share) {
        final sharing = context.read<LiveShareCubit>();
        return FloatingActionButton.extended(
          heroTag: 'live-share',
          onPressed: share.isStarting
              ? null
              : () => _showLiveShareActions(context, sharing),
          backgroundColor: share.isActive && share.connectedRelays > 0
              ? kMint
              : AppColors.secondary.background,
          foregroundColor: share.isActive && share.connectedRelays > 0
              ? Colors.black
              : AppColors.secondary.foreground,
          icon: share.isStarting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  share.isActive && share.connectedRelays > 0
                      ? Icons.share_location_rounded
                      : Icons.share_location_outlined,
                ),
          label: Text(
            share.isStarting
                ? l10n.liveSharePreparing
                : share.isActive
                ? share.connectedRelays > 0
                      ? l10n.liveShareConnected
                      : l10n.liveShareDisconnected
                : l10n.liveShareButton,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  Future<void> _showLiveShareActions(
    BuildContext context,
    LiveShareCubit sharing,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (!sharing.state.isActive) {
      var password = '';
      var obscurePassword = true;
      final start = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            scrollable: true,
            title: Text(l10n.liveShareTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.liveSharePasswordHelp),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => password = value,
                  obscureText: obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: l10n.liveSharePassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: obscurePassword
                          ? l10n.showPassword
                          : l10n.hidePassword,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.btnCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.shareTooltip),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || start != true) return;
      await _shareLiveLink(
        context,
        sharing,
        password: password.isEmpty ? null : password,
      );
      return;
    }
    final action = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.liveShareTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.btnStop),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.shareTooltip),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return;
    if (action) {
      await _shareLiveLink(context, sharing);
    } else {
      await sharing.stop();
    }
  }
}
