import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/app/global.dart';
import 'package:furtive/features/settings/settings_page.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ui_kit/ui_kit.dart';

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
          home: SettingsPage(
            onOpenPermissions: () {},
            onOpenPreferences: () {},
            onOpenLogs: () {},
            onOpenOfflineMaps: () {},
            onOpenChangelog: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('version 1.3.0+3'), 150);
      expect(find.text('version 1.3.0+3').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('the changelog is reachable from the menu', (tester) async {
    Global.app = PackageInfo(
      appName: 'Furtive',
      packageName: 'test',
      version: '1.3.0',
      buildNumber: '3',
    );
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(
          onOpenPermissions: () {},
          onOpenPreferences: () {},
          onOpenLogs: () {},
          onOpenOfflineMaps: () {},
          onOpenChangelog: () => opened++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The row reuses the changelog page's own title rather than a label of
    // its own, so this is the string the page is headed with.
    await tester.tap(find.text("What's new"));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
