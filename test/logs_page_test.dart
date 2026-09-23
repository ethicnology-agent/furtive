import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/logs.dart';
import 'package:furtive/core/theme.dart';
import 'package:furtive/features/logs/logs_page.dart';
import 'package:furtive/l10n/app_localizations.dart';

class _MemoryLogs implements MyLogs {
  List<String> lines = [];
  bool failRead = false;
  int deletions = 0;
  @override
  Future<List<String>> readLogs() async {
    if (failRead) throw StateError('storage unavailable');
    return List.of(lines);
  }

  @override
  Future<void> deleteLogs() async {
    deletions++;
    lines.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MyLogs original;
  late _MemoryLogs storage;
  String? clipboard;
  setUp(() {
    original = logs;
    storage = _MemoryLogs();
    logs = storage;
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() {
    logs = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LogsPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty logs disable copying and deletion', (tester) async {
    await open(tester);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.copy_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets(
    'logs are sorted newest first and copied without display formatting',
    (tester) async {
      storage.lines = [
        '2026-01-01T10:00:00.000\tINFO\tOlder',
        '2026-01-02T10:00:00.000\tWARNING\tNewer',
      ];
      await open(tester);
      expect(
        tester.getTopLeft(find.textContaining('Newer')).dy,
        lessThan(tester.getTopLeft(find.textContaining('Older')).dy),
      );
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, '${storage.lines[1]}\n${storage.lines[0]}');
      final row = find
          .ancestor(
            of: find.textContaining('Older'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is GestureDetector && widget.onLongPress != null,
            ),
          )
          .first;
      await tester.longPressAt(tester.getTopLeft(row) + const Offset(2, 10));
      await tester.pumpAndSettle();
      expect(clipboard, storage.lines[0]);
    },
  );
  testWidgets('deletion requires confirmation and reloads the empty state', (
    tester,
  ) async {
    storage.lines = ['2026-01-01T10:00:00.000\tSEVERE\tFailure'];
    await open(tester);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.deletions, 0);
    expect(find.textContaining('Failure'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(storage.deletions, 1);
    expect(find.textContaining('Failure'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.copy_rounded),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('read failure leaves loading and explains the storage error', (
    tester,
  ) async {
    storage.failRead = true;
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('storage unavailable'), findsOneWidget);
  });
  testWidgets('date filter can be cancelled without hiding entries', (
    tester,
  ) async {
    storage.lines = ['2026-01-01T10:00:00.000\tINFO\tVisible'];
    await open(tester);
    await tester.tap(find.byIcon(Icons.date_range_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Visible'), findsOneWidget);
  });

  testWidgets(
    'date range includes both days and copies only matching entries',
    (tester) async {
      storage.lines = [
        '2026-01-01T00:00:00.000\tINFO\tFirst day',
        '2026-01-02T23:59:59.999\tWARNING\tLast day',
        '2025-12-31T23:59:59.999\tINFO\tBefore',
        '2026-01-03T00:00:00.000\tINFO\tAfter',
        'invalid\tINFO\tMalformed',
      ];
      await open(tester);
      await tester.tap(find.byIcon(Icons.date_range_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '01/01/2026');
      await tester.enterText(fields.at(1), '01/02/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('First day'), findsOneWidget);
      expect(find.textContaining('Last day'), findsOneWidget);
      expect(find.textContaining('Before'), findsNothing);
      expect(find.textContaining('After'), findsNothing);
      expect(find.textContaining('Malformed'), findsNothing);
      await tester.tap(find.byTooltip('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, '${storage.lines[1]}\n${storage.lines[0]}');
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(find.textContaining('Before'), findsOneWidget);
      expect(find.textContaining('After'), findsOneWidget);
      expect(find.textContaining('Malformed'), findsOneWidget);
    },
  );
}
