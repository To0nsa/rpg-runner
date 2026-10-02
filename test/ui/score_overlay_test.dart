import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/ui/hud/game/score_overlay.dart';
import 'package:rpg_runner/ui/leaderboard/run_result.dart';

import '../support/test_level.dart';
import '../test_tunings.dart';

void main() {
  testWidgets('live distance and terminal result share the 25-unit metre', (
    tester,
  ) async {
    final core = GameCore(
      seed: 1,
      levelDefinition: testFieldLevel(
        tuning: const CoreTuning(
          camera: noAutoscrollCameraTuning,
          track: TrackTuning(enabled: false),
        ),
      ),
      playerCharacter: testPlayerCharacter,
    );
    final controller = GameController(core: core);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScoreOverlay(controller: controller),
      ),
    );
    expect(find.text('Distance 0m'), findsOneWidget);

    final startX = core.playerPosX;
    for (var tick = 1; tick <= 60; tick++) {
      controller.enqueue(MoveAxisCommand(tick: tick, axis: 1));
      controller.advanceFrame(1 / 60);
    }
    await tester.pump();
    final expectedMeters = ((core.playerPosX - startX) / 25).floor();
    expect(expectedMeters, greaterThan(5));
    expect(find.text('Distance ${expectedMeters}m'), findsOneWidget);

    core.giveUp();
    final event = core.drainEvents().whereType<RunEndedEvent>().single;
    final result = buildRunResult(
      event: event,
      scoreTuning: core.scoreTuning,
      tickHz: 60,
      endedAtMs: 0,
    );
    expect(result.distanceMeters, expectedMeters);
  });
}
