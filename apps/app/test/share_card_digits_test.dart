import 'package:activities/activities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/features/activities/widgets/share_card.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:geo/geo.dart';
import 'package:intl/intl.dart' show DateFormat;

/// One image, one numbering system.
///
/// The card's date is formatted by `intl` and its figures are not, so in a
/// locale whose dates use non-ASCII digits the two disagreed. A golden can
/// only say that some pixels moved; this says which characters must match,
/// and it covers `bn` as well as `ar` — the two locales of the 26 shipped
/// where `DateFormat` does not use ASCII digits.
void main() {
  ActivityEntity activity() {
    final start = DateTime(2026, 7, 26, 8, 30);
    return ActivityEntity(
      id: 'digits',
      name: '',
      description: '',
      createdAt: start,
      startedAt: start,
      stoppedAt: start.add(const Duration(minutes: 6, seconds: 30)),
      points: [
        for (var i = 0; i < 40; i++)
          ActivityPointEntity(
            position: PositionEntity(
              latitude: 48.85 + i * 0.0002,
              longitude: 2.35,
              elevation: 30 + i * 0.5,
            ),
            time: start.add(Duration(seconds: i * 10)),
            status: ActivityPointStatusEntity.active,
          ),
      ],
    );
  }

  /// Every decimal digit rendered anywhere on the card.
  Set<String> digitsOn(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .expand((s) => s.split(''))
      .where(_isDigit)
      .toSet();

  for (final tag in ['ar', 'bn', 'en', 'fr']) {
    testWidgets('the card shows one numbering system in $tag', (tester) async {
      tester.view.physicalSize = const Size(ShareCard.width, ShareCard.height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(tag),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: tag == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: ShareCard(activity: activity()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // What the date formatter uses, derived the same way the card does.
      final year = DateFormat('yyyy', tag).format(DateTime(2000));
      final zero = year.codeUnitAt(year.length - 1);
      final expected = {
        for (var d = 0; d < 10; d++) String.fromCharCode(zero + d),
      };

      final shown = digitsOn(tester);
      expect(shown, isNotEmpty, reason: 'the card renders no digits at all');
      expect(
        shown.difference(expected),
        isEmpty,
        reason: 'digits outside the locale\'s numbering system: $shown',
      );
    });
  }
}

bool _isDigit(String c) {
  final u = c.codeUnitAt(0);
  // The decimal blocks this application can meet: ASCII, Arabic-Indic and
  // Bengali. Listed rather than detected so an unexpected script is a
  // failure here rather than something quietly ignored.
  return (u >= 0x30 && u <= 0x39) ||
      (u >= 0x0660 && u <= 0x0669) ||
      (u >= 0x09E6 && u <= 0x09EF);
}
