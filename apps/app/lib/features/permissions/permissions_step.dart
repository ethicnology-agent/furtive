import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/features/permissions/bloc/permissions_bloc.dart';
import 'package:furtive/features/permissions/bloc/permissions_event.dart';
import 'package:furtive/features/permissions/bloc/permissions_state.dart';
import 'package:furtive/features/permissions/permission_entity.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ui_kit/ui_kit.dart';

/// The permission step a wizard shows.
///
/// It used to be a private widget inside the onboarding wizard, which meant
/// the wizard implemented a permissions interface rather than showing one:
/// it owned this feature's bloc, reloaded it when the app resumed, and read
/// its state to decide whether the wizard could finish. The wizard has a step
/// to fill and one question to ask of it — may the user move on — and
/// everything behind that answer belongs here.
class PermissionsStep extends StatefulWidget {
  const PermissionsStep({super.key, this.onRequiredGrantedChanged});

  /// Told whether the permissions this app cannot run without are granted.
  ///
  /// The wizard gates its finish button on this rather than on a permissions
  /// state, so it never learns what a permission is.
  final ValueChanged<bool>? onRequiredGrantedChanged;

  @override
  State<PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends State<PermissionsStep>
    with WidgetsBindingObserver {
  late final PermissionsBloc _bloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloc = PermissionsBloc()..add(const LoadPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android 11+ locationAlways requires the user to go to system settings
    // and come back. Refresh when the app resumes.
    if (state == AppLifecycleState.resumed) {
      _bloc.add(const LoadPermissions());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: _PermissionsList(
        onRequiredGrantedChanged: widget.onRequiredGrantedChanged,
      ),
    );
  }
}

class _PermissionsList extends StatelessWidget {
  const _PermissionsList({this.onRequiredGrantedChanged});

  final ValueChanged<bool>? onRequiredGrantedChanged;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PermissionsBloc, PermissionsState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage ||
          previous.requiredGranted != current.requiredGranted,
      listener: (context, state) {
        onRequiredGrantedChanged?.call(state.requiredGranted);
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!.message),
              backgroundColor: AppColors.destructive.background,
              duration: const Duration(seconds: 3),
            ),
          );
          context.read<PermissionsBloc>().add(const ClearPermissionsError());
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.permissions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            for (var i = 0; i < state.permissions.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _PermissionCard(permission: state.permissions[i]),
            ],
          ],
        );
      },
    );
  }
}

// Map the runtime Permission to the localised name/description copies in
// app_*.arb. Unknown permissions fall back to the entity's hardcoded text
// so newly-added permissions don't break the build.
String _localizedName(BuildContext context, PermissionEntity p) {
  final l10n = AppLocalizations.of(context);
  if (p.permission == Permission.locationWhenInUse) {
    return l10n.permLocationWhileUsingName;
  }
  if (p.permission == Permission.locationAlways) {
    return l10n.permLocationAlwaysName;
  }
  if (p.permission == Permission.notification) {
    return l10n.permNotificationName;
  }
  return p.name;
}

String _localizedDescription(BuildContext context, PermissionEntity p) {
  final l10n = AppLocalizations.of(context);
  if (p.permission == Permission.locationWhenInUse) {
    return l10n.permLocationWhileUsingDesc;
  }
  if (p.permission == Permission.locationAlways) {
    return l10n.permLocationAlwaysDesc;
  }
  if (p.permission == Permission.notification) {
    return l10n.permNotificationDesc;
  }
  return p.description;
}

class _PermissionCard extends StatelessWidget {
  final PermissionEntity permission;
  const _PermissionCard({required this.permission});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  permission.isGranted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: permission.isGranted ? kMint : kTextMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _localizedName(context, permission),
                    style: textTheme.titleMedium,
                  ),
                ),
                if (permission.isOptional)
                  Text(
                    AppLocalizations.of(context).permOptional,
                    style: textTheme.labelSmall,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                _localizedDescription(context, permission),
                style: textTheme.bodySmall,
              ),
            ),
            if (!permission.isGranted) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: OutlinedButton(
                  onPressed: () => context.read<PermissionsBloc>().add(
                    RequestPermission(permission.permission),
                  ),
                  child: Text(AppLocalizations.of(context).btnGrant),
                ),
              ),
            ],
            if (permission.isPermanentlyDenied)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 8),
                child: Text(
                  AppLocalizations.of(context).permDeniedMsg,
                  style: textTheme.bodySmall?.copyWith(color: kWarning),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
