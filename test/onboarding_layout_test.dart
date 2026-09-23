import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/database/local_database.dart';
import 'package:furtive/core/entities/preferences_entity.dart';
import 'package:furtive/core/locator.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/core/widgets/labeled_dropdown.dart';
import 'package:furtive/features/onboarding/onboarding_page.dart';
import 'package:furtive/l10n/app_localizations.dart';

void main() {
  const permissionsChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  late LocalDatabase db;

  setUp(() {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    getIt.registerSingleton<LocalDatabase>(db);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, (call) async {
          if (call.method == 'checkPermissionStatus') return 0;
          throw UnsupportedError(call.method);
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, null);
    await getIt.unregister<LocalDatabase>();
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
          home: const OnboardingPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

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
}
