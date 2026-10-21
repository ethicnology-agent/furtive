import 'package:diagnostics/diagnostics.dart';
import 'package:flutter/material.dart';
import 'package:furtive/app/global.dart';
import 'package:furtive/labels/ui_languages.dart';
import 'package:furtive/labels/map_theme_name.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:preferences/preferences.dart';
import 'package:ui_kit/ui_kit.dart';

/// First-launch wizard:
/// 1. Welcome
/// 2. Settings (theme + UI language)
/// 3. Permissions (locationWhenInUse required; locationAlways optional).
///    Finish is disabled until locationWhenInUse is granted.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.permissionsStep,
    required this.onFinished,
    this.onPreviewLocale,
  });

  /// Called once the wizard has stored what the user chose.
  ///
  /// Where a finished wizard lands is not the wizard's to know — it used to
  /// push the home shell itself, which is a feature deciding what the
  /// application opens on.
  final VoidCallback onFinished;

  /// Applies a UI language before it is stored, so the user sees the choice.
  ///
  /// A preview, not a setting: nothing is persisted until the wizard
  /// finishes, which is the one case the settings subscription cannot serve.
  /// Whoever holds the live locale performs it; the wizard only says which.
  final ValueChanged<String?>? onPreviewLocale;

  /// What fills the third step, and how it reports that the user may finish.
  ///
  /// A slot rather than a widget this wizard builds: the step is another
  /// feature's, and the only thing the wizard needs back from it is whether
  /// the finish button may light up.
  final Widget Function(ValueChanged<bool> onReady) permissionsStep;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  final _preferences = PreferencesRepository();

  MapThemeEntity _theme = MapThemeEntity.dark;
  String? _uiLocale; // null = follow system
  int _currentStep = 0;
  bool _saving = false;
  bool _canFinish = false;

  static const _stepCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_saving) return;
    if (_currentStep < _stepCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _finish();
    }
  }

  Future<void> _previous() async {
    if (_saving || _currentStep == 0) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      // Read the current persisted preferences and copyWith only what this
      // wizard actually edits — building a PreferencesEntity by hand here
      // silently reset every OTHER field (checkUpdates, mapTilesEnabled,
      // showOnLockScreen, ...) to its constructor default. Harmless the
      // first time onboarding runs (those already match the fresh-install
      // DB defaults), but this path is also hit if onboarding is ever
      // re-entered (e.g. a future "reset onboarding" support flow), where it
      // would silently clobber preferences the user had already changed.
      final current = await _preferences.fetch();
      await _preferences.store(
        current.copyWith(
          mapTheme: _theme,
          hasCompletedOnboarding: true,
          uiLocale: _uiLocale,
          // Stamp the current version so the post-upgrade changelog doesn't
          // immediately pop in front of a user who just finished onboarding.
          lastShownChangelogVersion: Global.app.version,
        ),
      );
      // Nothing is applied by hand here. Both the locale and the map watch
      // the settings: storing them above is what makes the chosen language
      // and theme take effect, and the map re-resolves its style only if one
      // of the three things it is built from actually changed.

      if (!mounted) return;
      widget.onFinished();
    } catch (e, st) {
      logs.severe('Onboarding finish', error: e, trace: st);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.destructive.background,
          content: Text(
            AppLocalizations.of(context).onboardSaveError(e.toString()),
            style: TextStyle(color: AppColors.destructive.foreground),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0 && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _previous();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _ProgressIndicator(step: _currentStep, total: _stepCount),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    _WelcomeStep(),
                    _SettingsStep(
                      theme: _theme,
                      uiLocale: _uiLocale,
                      onThemeChanged: (v) => setState(() => _theme = v),
                      onUiLocaleChanged: (v) {
                        setState(() => _uiLocale = v);
                        widget.onPreviewLocale?.call(v);
                      },
                    ),
                    _StepShell(
                      title: AppLocalizations.of(
                        context,
                      ).onboardPermissionsTitle,
                      subtitle: AppLocalizations.of(
                        context,
                      ).onboardPermissionsSubtitle,
                      child: widget.permissionsStep(
                        (ready) => setState(() => _canFinish = ready),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.screenPadding,
                  vertical: MediaQuery.sizeOf(context).shortestSide * 0.1,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      final isLastStep = _currentStep == _stepCount - 1;
                      final canFinish = !isLastStep || _canFinish;
                      return Row(
                        children: [
                          if (_currentStep > 0) ...[
                            Flexible(
                              child: TextButton(
                                onPressed: _saving ? null : _previous,
                                child: Text(
                                  AppLocalizations.of(context).btnBack,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_saving || !canFinish) ? null : _next,
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      isLastStep
                                          ? AppLocalizations.of(
                                              context,
                                            ).btnFinish
                                          : AppLocalizations.of(
                                              context,
                                            ).btnNext,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(total, (i) {
          final filled = i <= step;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: filled
                    ? AppColors.primary.background
                    : AppColors.tertiary.background,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _StepShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                    color: AppColors.tertiary.foreground,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          // Keep the welcome illustration centered on tall screens while
          // allowing the entire step to scroll on short screens or large text.
          SliverFillRemaining(hasScrollBody: false, child: child),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepShell(
      title: l10n.onboardWelcomeTitle,
      subtitle: l10n.onboardWelcomeSubtitle,
      child: Center(
        child: Icon(
          Icons.directions_run_rounded,
          size: 96,
          color: AppColors.primary.background,
        ),
      ),
    );
  }
}

class _SettingsStep extends StatelessWidget {
  final MapThemeEntity theme;
  final String? uiLocale;
  final ValueChanged<MapThemeEntity> onThemeChanged;
  final ValueChanged<String?> onUiLocaleChanged;

  const _SettingsStep({
    required this.theme,
    required this.uiLocale,
    required this.onThemeChanged,
    required this.onUiLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _StepShell(
      title: l10n.onboardSettingsTitle,
      subtitle: l10n.onboardSettingsSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.settingsThemeLabel,
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LabeledDropdown<MapThemeEntity>(
            value: theme,
            items: MapThemeEntity.values,
            labelFor: (t) => mapThemeName(AppLocalizations.of(context), t),
            onChanged: onThemeChanged,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.settingsUiLanguageLabel,
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LabeledDropdown<String?>(
            value: uiLocale,
            items: uiLanguageOptions,
            labelFor: (code) => code == null
                ? l10n.settingsUiLanguageSystem
                : (uiLanguageNativeNames[code] ?? code.toUpperCase()),
            onChanged: onUiLocaleChanged,
          ),
        ],
      ),
    );
  }
}
