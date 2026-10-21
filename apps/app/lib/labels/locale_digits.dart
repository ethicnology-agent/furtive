import 'package:intl/intl.dart';

/// Rewrites the ASCII digits in [text] as the digits [DateFormat] uses for
/// [locale].
///
/// `intl` disagrees with itself here. For `ar` its date symbols use the
/// Arabic-Indic digits while its number symbols use ASCII ones, so a card
/// that formats its date with `DateFormat` and its figures with
/// `toStringAsFixed` shows two numbering systems side by side. Of the 26
/// locales this application ships, `ar` and `bn` render dates in non-ASCII
/// digits; `bn` is the one where `NumberFormat` agrees.
///
/// This follows the date, deliberately: the date is the only figure on the
/// card that is already localised, and making the rest match it is what
/// keeps one image from mixing two scripts.
///
/// Only the digits are rewritten. The decimal separator stays whatever the
/// string was built with, because that is what `intl`'s number data says for
/// both locales.
String localeDigits(String text, String locale) {
  final offset = _offsets.putIfAbsent(locale, () => _deriveOffset(locale));
  if (offset == 0) return text;
  return String.fromCharCodes([
    for (final unit in text.codeUnits)
      unit >= _asciiZero && unit <= _asciiNine ? unit + offset : unit,
  ]);
}

const _asciiZero = 0x30;
const _asciiNine = 0x39;

final _offsets = <String, int>{};

/// How far this locale's digits sit from the ASCII ones.
///
/// Derived rather than tabulated: `yyyy` is a pattern of pure digits with no
/// localised literal in it, so every character of a formatted year is a digit
/// of the locale's numbering system — and the year 2000 ends in a zero. A
/// table would be a second copy of CLDR, going stale on its own schedule.
int _deriveOffset(String locale) {
  try {
    final year = DateFormat('yyyy', locale).format(DateTime(2000));
    return year.codeUnitAt(year.length - 1) - _asciiZero;
  } on Exception {
    // An uninitialised locale is not a reason to lose the figures.
    return 0;
  }
}
