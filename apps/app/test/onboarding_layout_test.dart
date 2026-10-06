import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:activities/testing.dart';
import 'package:furtive/features/onboarding/onboarding_page.dart';
import 'package:furtive/features/permissions/permissions_step.dart';
import 'package:furtive/l10n/app_localizations.dart';
import 'package:preferences/preferences.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  late LocalDatabase db;

  setUp(() {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    LocalDatabase.installSharedForTesting(db);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 0;
          throw UnsupportedError(call.method);
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, null);
    await db.close();
  });

  for (final scenario in [
    (name: 'landscape', size: const Size(800, 360), scale: 1.0),
    (name: 'landscape with large text', size: const Size(800, 360), scale: 2.0),
    (name: 'portrait', size: const Size(360, 800), scale: 1.0),
  ]) {
    testWidgets('onboarding controls remain reachable in ${scenario.name}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.scale),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child!,
          ),
          home: OnboardingPage(
            permissionsStep: (onReady) =>
                PermissionsStep(onRequiredGrantedChanged: onReady),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Back').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        find.byType(LabeledDropdown<MapThemeEntity>).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      final verticalScrollable = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last;
      for (final dropdown in [
        find.byType(LabeledDropdown<MapThemeEntity>),
        find.byType(LabeledDropdown<String?>),
      ]) {
        await tester.scrollUntilVisible(
          dropdown,
          100,
          scrollable: verticalScrollable,
        );
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        expect(dropdown.hitTestable(), findsOneWidget);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Close the menu without changing preferences or leaving onboarding.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }

      expect(find.text('Next').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Notifications'),
        100,
        scrollable: verticalScrollable,
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Grant').last);
      await tester.pumpAndSettle();
      expect(find.text('Grant').last.hitTestable(), findsOneWidget);
      expect(find.text('Finish').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the wizard finishes only once its step says it may', (
    tester,
  ) async {
    // The gate used to read the permissions state directly. It now only
    // hears a bool from whatever fills the last step, so prove the wizard
    // still refuses to finish until it is told, and stops refusing when it
    // is — without a permission anywhere in sight.
    late ValueChanged<bool> report;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingPage(
          permissionsStep: (onReady) {
            report = onReady;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    ElevatedButton finish() =>
        tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
    expect(find.text('Finish'), findsOneWidget);
    expect(finish().onPressed, isNull);

    report(true);
    await tester.pumpAndSettle();
    expect(finish().onPressed, isNotNull);

    report(false);
    await tester.pumpAndSettle();
    expect(finish().onPressed, isNull);
  });
}
