import 'dart:async';

import 'package:diagnostics/diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:furtive/app/global.dart';
import 'package:furtive/app/locale_cubit.dart';
import 'package:furtive/features/permissions/version.dart';
import 'package:furtive/app/bottom_navigation_widget.dart';
import 'package:furtive/features/changelog/changelog_entries.dart';
import 'package:furtive/features/changelog/pages/changelog_page.dart';
import 'package:furtive/features/onboarding/onboarding_page.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:furtive/features/permissions/bloc/permissions_bloc.dart';
import 'package:furtive/features/permissions/bloc/permissions_event.dart';
import 'package:furtive/features/permissions/bloc/permissions_state.dart';
import 'package:furtive/features/permissions/pages/permissions_page.dart';
import 'package:furtive/features/permissions/permissions_step.dart';
import 'package:preferences/preferences.dart';

/// Decides what the application opens on.
///
/// It lived in the permissions feature because it checks permissions, but
/// checking is not what it is for: it chooses between the onboarding wizard,
/// the post-upgrade changelog, the permission recovery page and the home
/// shell. That is routing across four journeys, which is the shell's job and
/// no feature's.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _hasNavigated = false;
  String? _navigationError;
  final _preferences = PreferencesRepository();

  @override
  void initState() {
    super.initState();
    context.read<PermissionsBloc>().add(const LoadPermissions());
  }

  Future<void> _navigate(bool allGranted) async {
    if (_hasNavigated || !mounted) return;
    setState(() {
      _hasNavigated = true;
      _navigationError = null;
    });

    final PreferencesEntity prefs;
    try {
      prefs = await _preferences.fetch();
    } catch (error, trace) {
      logs.severe('Load startup preferences', error: error, trace: trace);
      if (mounted) {
        setState(() {
          _hasNavigated = false;
          _navigationError = error.toString();
        });
      }
      return;
    }
    if (!mounted) return;

    // Show the post-upgrade changelog before the main UI, but only for
    // existing users who came from an older version. Fresh installs
    // (lastShownChangelogVersion == null until the wizard finishes) skip it.
    final lastSeen = prefs.lastShownChangelogVersion;
    if (prefs.hasCompletedOnboarding &&
        lastSeen != null &&
        lastSeen != Global.app.version) {
      // Only the releases newer than what the user last saw — so an upgrade
      // never shows stale "what's new" for a version they've already seen,
      // and a build with no matching release entry shows nothing.
      final newer = changelogReleases(
        AppLocalizations.of(context),
      ).where((r) => isNewerVersion(r.version, lastSeen)).toList();
      if (newer.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChangelogPage(releases: newer)),
        );
        if (!mounted) return;
      }
      try {
        // Persist the current version regardless, so the gate doesn't
        // re-evaluate on every launch once we've considered this upgrade.
        await _preferences.store(
          prefs.copyWith(lastShownChangelogVersion: Global.app.version),
        );
      } catch (e, st) {
        // Non-fatal — worst case the changelog shows again on next launch.
        logs.warning(
          'Failed to persist changelog version',
          error: e,
          trace: st,
        );
      }
      if (!mounted) return;
    }

    // The wizard now owns the permissions step, so onboarding takes priority
    // over the standalone PermissionsPage. PermissionsPage is only used as a
    // recovery fallback when an onboarded user has had a required permission
    // revoked (e.g. via system settings while the app was backgrounded).
    final Widget destination;
    if (!prefs.hasCompletedOnboarding) {
      destination = _onboarding();
    } else if (!allGranted) {
      destination = PermissionsPage(onContinue: _afterPermissions);
    } else {
      destination = const BottomNavigationWidget();
    }

    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  /// Where a user lands once they have granted what was missing.
  ///
  /// Re-read rather than remembered: a fresh install that reached the
  /// permission page because permissions were denied must still see the
  /// wizard once they are granted, and the flag may have been written
  /// between this gate running and the user finishing.
  Future<void> _afterPermissions() async {
    final prefs = await _preferences.fetch();
    if (!mounted) return;
    final destination = prefs.hasCompletedOnboarding
        ? const BottomNavigationWidget()
        : _onboarding();
    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  /// The wizard, with the permission step this app's permissions feature
  /// fills. The wizard asks for a step; choosing which one is the shell's.
  Widget _onboarding() => Builder(
    builder: (context) => OnboardingPage(
      permissionsStep: (onReady) =>
          PermissionsStep(onRequiredGrantedChanged: onReady),
      onPreviewLocale: context.read<LocaleCubit>().setLocale,
      onFinished: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BottomNavigationWidget()),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocListener<PermissionsBloc, PermissionsState>(
      listener: (context, state) {
        if (!state.isLoading) _navigate(state.requiredGranted);
      },
      child: Scaffold(
        body: Center(
          child: _navigationError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_navigationError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _navigate(
                          context.read<PermissionsBloc>().state.requiredGranted,
                        ),
                        child: Text(AppLocalizations.of(context).btnRetry),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
