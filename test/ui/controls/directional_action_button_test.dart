import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/directional_action_button.dart';

void main() {
  testWidgets('commits on release when not force-canceled', (tester) async {
    final aimPreview = AimPreviewModel();
    final forceCancelSignal = ValueNotifier<int>(0);
    const controls = ControlsTuning.fixed;
    var commitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DirectionalActionButton(
              label: 'Proj',
              icon: Icons.auto_awesome,
              onAimDir: (_, _) {},
              onAimClear: () {},
              onCommit: () => commitCount += 1,
              projectileAimPreview: aimPreview,
              tuning: controls.style.directionalActionButton,
              size: controls.style.directionalActionButton.size,
              deadzoneRadius:
                  controls.style.directionalActionButton.deadzoneRadius,
              cooldownRing: controls.style.cooldownRing,
              forceCancelSignal: forceCancelSignal,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(DirectionalActionButton));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(commitCount, 1);

    aimPreview.dispose();
    forceCancelSignal.dispose();
  });

  testWidgets('force-cancel signal prevents commit on release', (tester) async {
    final aimPreview = AimPreviewModel();
    final forceCancelSignal = ValueNotifier<int>(0);
    const controls = ControlsTuning.fixed;
    var commitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DirectionalActionButton(
              label: 'Proj',
              icon: Icons.auto_awesome,
              onAimDir: (_, _) {},
              onAimClear: () {},
              onCommit: () => commitCount += 1,
              projectileAimPreview: aimPreview,
              tuning: controls.style.directionalActionButton,
              size: controls.style.directionalActionButton.size,
              deadzoneRadius:
                  controls.style.directionalActionButton.deadzoneRadius,
              cooldownRing: controls.style.cooldownRing,
              forceCancelSignal: forceCancelSignal,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(DirectionalActionButton));
    final gesture = await tester.startGesture(center);
    await tester.pump();

    forceCancelSignal.value += 1;
    await tester.pump();

    await gesture.up();
    await tester.pump();

    expect(commitCount, 0);
    expect(aimPreview.value.active, isFalse);

    aimPreview.dispose();
    forceCancelSignal.dispose();
  });
}
