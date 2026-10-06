import 'package:furtive/l10n/app_localizations.dart';
import 'package:preferences/preferences.dart';

/// Localised display name for a map theme.
///
/// It lived in the preferences page, which made the onboarding wizard import
/// another feature's page to label a picker. The wording belongs to neither
/// of them: both features show the same list, so the shell owns the names.
String mapThemeName(AppLocalizations l10n, MapThemeEntity theme) =>
    switch (theme) {
      MapThemeEntity.light => l10n.prefThemeLight,
      MapThemeEntity.dark => l10n.prefThemeDark,
      MapThemeEntity.white => l10n.prefThemeWhite,
      MapThemeEntity.grayscale => l10n.prefThemeGrayscale,
      MapThemeEntity.black => l10n.prefThemeBlack,
    };
