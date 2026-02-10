import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/move_buttons.dart';

void main() {
  testWidgets('slide-switches movement side without lifting the pointer', (
    tester,
  ) async {
    final emittedAxis = <double>[];
    const moveButtons = MoveButtonsTuning(
      buttonWidth: 64,
      buttonHeight: 48,
      gap: 8,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MoveButtons(
              onAxisChanged: emittedAxis.add,
              tuning: moveButtons,
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(MoveButtons));
    final start = Offset(rect.left + 4, rect.center.dy);
    final end = Offset(rect.right - 4, rect.center.dy);

    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(emittedAxis, equals(<double>[-1.0, 1.0, 0.0]));
  });
}
