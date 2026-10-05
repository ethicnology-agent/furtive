import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furtive/core/widgets/hold_to_confirm_button.dart';

void main() {
  Widget subject(VoidCallback onConfirmed) => MaterialApp(
    home: Scaffold(
      floatingActionButton: SizedBox(
        width: 184,
        child: HoldToConfirmButton(
          icon: Icons.stop,
          label: 'Stop',
          shortTapHint: 'Hold for three seconds to stop',
          progressLabel: (seconds) => 'Keep holding: $seconds',
          onConfirmed: onConfirmed,
        ),
      ),
    ),
  );

  testWidgets('shows progress away from the button and cancels on release', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(subject(() => confirmations++));
    final target = find.byType(HoldToConfirmButton);
    final gesture = await tester.startGesture(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));

    final progress = find.byType(LinearProgressIndicator);
    expect(progress, findsOneWidget);
    expect(
      tester.getRect(progress).bottom,
      lessThan(tester.getRect(target).top),
    );
    expect(find.text('Stop'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(progress, findsNothing);
    expect(confirmations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirms once after a full hold with start and finish haptics', (
    tester,
  ) async {
    var confirmations = 0;
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(subject(() => confirmations++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // Establish the ticker's first frame before advancing its duration.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(confirmations, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(confirmations, 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  testWidgets('backgrounding cancels a hold even before pointer cancellation', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(subject(() => confirmations++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
    await tester.pump(const Duration(seconds: 4));
    expect(confirmations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during a hold removes the progress overlay', (
    tester,
  ) async {
    var confirmations = 0;
    await tester.pumpWidget(subject(() => confirmations++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToConfirmButton)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(confirmations, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
