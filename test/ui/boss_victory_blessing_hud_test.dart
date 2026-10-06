import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/ui/hud/game/boss_arena_hud.dart';

import '../../packages/runner_core/test/test_support/boss_victory_fixture.dart';

void main() {
  testWidgets('victory attribution survives pause and expires on Core ticks', (
    tester,
  ) async {
    final core = bossVictoryCore();
    advanceToBossBlessing(core);
    final controller = GameController(core: core);
    addTearDown(controller.dispose);
    final duration = controller.snapshot.bossVictoryBlessing!.durationTicks;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BossArenaHud(controller: controller)),
      ),
    );
    const title = 'Bénédiction des Dames de la forêt';
    expect(find.text(title), findsOneWidget);
    expect(find.text('+60 % santé · mana · endurance'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text(title), findsOneWidget);
    controller.setPaused(true);
    final startTick = core.tick;
    controller.advanceFrame(10);
    await tester.pump();
    expect(core.tick, startTick);
    expect(find.text(title), findsOneWidget);

    controller.setPaused(false);
    for (var n = 0; n < duration - 1; n++) {
      controller.advanceFrame(1 / core.tickHz);
    }
    await tester.pump();
    expect(find.text(title), findsOneWidget);
    controller.advanceFrame(1 / core.tickHz);
    await tester.pump();
    expect(find.text(title), findsNothing);
    expect(controller.snapshot.bossVictoryBlessing, isNull);
    expect(tester.takeException(), isNull);
  });
}
