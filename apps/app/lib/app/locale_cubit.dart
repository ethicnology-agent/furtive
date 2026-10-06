import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart';

/// The locale the application renders in.
///
/// It follows the stored setting rather than being told about it. The
/// settings page used to reach this cubit through the service locator after
/// every save, which meant a screen that changes a setting had to know every
/// other thing that reads one.
///
/// [setLocale] stays public for the one case a subscription cannot serve:
/// the onboarding wizard previews a language before anything is stored, so
/// the user can read the step they are on in the language they just picked.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(super.initialState, {PreferencesRepository? preferences}) {
    _subscription = (preferences ?? PreferencesRepository())
        .watch()
        .map((settings) => settings.uiLocale)
        .distinct()
        .listen(setLocale);
  }

  StreamSubscription<String?>? _subscription;

  void setLocale(String? tag) {
    emit(tag != null ? parseLocaleTag(tag) : null);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

/// Parse a stored locale tag into a Flutter [Locale]. Accepts `language`,
/// `language_COUNTRY`, or `language_Script_COUNTRY` (separator `_` or `-`).
/// Without this, `Locale('fr_CA')` would create a single-string language
/// code that never matches the generated `fr_CA` locale.
Locale parseLocaleTag(String tag) {
  final parts = tag.split(RegExp(r'[_-]'));
  if (parts.length == 1) return Locale(parts[0]);
  if (parts.length == 2) return Locale(parts[0], parts[1]);
  return Locale.fromSubtags(
    languageCode: parts[0],
    scriptCode: parts[1],
    countryCode: parts[2],
  );
}
