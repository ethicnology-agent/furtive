import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  Widget host<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T> onChanged,
    String Function(T)? labelFor,
  }) => MaterialApp(
    theme: appTheme,
    home: Scaffold(
      body: LabeledDropdown<T>(
        value: value,
        items: items,
        labelFor: labelFor ?? (item) => '$item',
        onChanged: onChanged,
      ),
    ),
  );

  testWidgets('renders the current selection through labelFor', (tester) async {
    await tester.pumpWidget(
      host(
        value: 'fr',
        items: const ['en', 'fr'],
        labelFor: (code) => code == 'fr' ? 'Français' : 'English',
        onChanged: (_) {},
      ),
    );

    expect(find.text('Français'), findsOneWidget);
  });

  testWidgets('reports the item the user picks', (tester) async {
    String? picked;
    await tester.pumpWidget(
      host(
        value: 'en',
        items: const ['en', 'fr'],
        onChanged: (code) => picked = code,
      ),
    );

    await tester.tap(find.byType(LabeledDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fr').last);
    await tester.pumpAndSettle();

    expect(picked, 'fr');
  });

  testWidgets('lets null through when the type is nullable', (tester) async {
    // "Follow the device locale" is a real choice, not the absence of one, so
    // nullable T must be able to report null back.
    String? picked = 'unset';
    await tester.pumpWidget(
      host<String?>(
        value: 'en',
        items: const [null, 'en'],
        labelFor: (code) => code ?? 'System default',
        onChanged: (code) => picked = code,
      ),
    );

    await tester.tap(find.byType(LabeledDropdown<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System default').last);
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('keeps the trigger text legible rather than theme-filled', (
    tester,
  ) async {
    // The global inputDecorationTheme fills inputs with an accent that is
    // fine behind a text field and illegible behind dropdown trigger text;
    // this component exists to refuse it.
    await tester.pumpWidget(
      host(value: 'en', items: const ['en'], onChanged: (_) {}),
    );

    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(field.decoration.filled, isFalse);
  });
}
