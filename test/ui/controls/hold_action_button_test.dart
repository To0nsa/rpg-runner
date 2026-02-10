import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/hold_action_button.dart';

void main() {
  testWidgets('starts on pointer down and ends on pointer up', (tester) async {
    var startCount = 0;
    var endCount = 0;
    const controls = ControlsTuning.fixed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoldActionButton(
              label: 'Sec',
              icon: Icons.shield,
              onHoldStart: () => startCount += 1,
              onHoldEnd: () => endCount += 1,
              tuning: controls.style.actionButton,
              size: controls.style.actionButton.size,
              cooldownRing: controls.style.cooldownRing,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(HoldActionButton));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(startCount, 1);
    expect(endCount, 1);
  });
}
