import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/global.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/features/settings/settings_page.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  for (final size in [const Size(800, 360), const Size(360, 800)]) {
    testWidgets('settings remains scrollable with large text at $size', (
      tester,
    ) async {
      Global.app = PackageInfo(
        appName: 'Furtive',
        packageName: 'test',
        version: '1.3.0',
        buildNumber: '3',
      );
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('version 1.3.0+3'), 150);
      expect(find.text('version 1.3.0+3').hitTestable(), findsOneWidget);
    });
  }
}
