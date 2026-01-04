import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/game/game_controller.dart';
import 'package:walkscape_runner/ui/hud/game/survival_timer_overlay.dart';

import '../test_tunings.dart';

void main() {
  testWidgets('SurvivalTimerOverlay formats tick-based mm:ss', (tester) async {
    final core = GameCore(seed: 1, cameraTuning: noAutoscrollCameraTuning);
    final controller = GameController(core: core);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SurvivalTimerOverlay(controller: controller),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);

    for (var i = 0; i < 11; i += 1) {
      controller.advanceFrame(0.1);
    }
    await tester.pump();

    expect(find.text('00:01'), findsOneWidget);

    controller.dispose();
  });
}
