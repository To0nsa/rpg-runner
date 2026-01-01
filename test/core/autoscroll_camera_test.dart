import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/camera/v0_autoscroll_camera.dart';
import 'package:walkscape_runner/core/contracts/v0_render_contract.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/events/game_event.dart';
import 'package:walkscape_runner/core/game_core.dart';
import 'package:walkscape_runner/core/players/player_catalog.dart';
import 'package:walkscape_runner/core/tuning/v0_camera_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_movement_tuning.dart';

void main() {
  test('V0AutoscrollCamera: player past threshold pulls target forward', () {
    final movement = V0MovementTuningDerived.from(
      const V0MovementTuning(),
      tickHz: 60,
    );
    final tuning = V0CameraTuningDerived.from(
      const V0CameraTuning(),
      movement: movement,
    );

    final cam = V0AutoscrollCamera(
      viewWidth: v0VirtualWidth.toDouble(),
      tuning: tuning,
      initial: V0CameraState(
        centerX: v0VirtualWidth * 0.5,
        targetX: v0VirtualWidth * 0.5,
        speedX: 0.0,
      ),
    );

    final baselineTargetX = cam.state.targetX;

    // Player is far ahead, beyond the follow threshold.
    cam.updateTick(dtSeconds: 1.0 / 60.0, playerX: 2000.0);
    expect(cam.state.targetX, greaterThan(baselineTargetX));
    expect(cam.state.centerX, greaterThanOrEqualTo(v0VirtualWidth * 0.5));
  });

  test(
    'GameCore: falling behind camera ends run and emits RunEndedEvent once',
    () {
      final core = GameCore(
        seed: 1,
        tickHz: 20,
        playerCatalog: const PlayerCatalog(
          bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
        ),
      );

      RunEndedEvent? ended;
      for (var i = 0; i < 200; i += 1) {
        core.stepOneTick();
        for (final e in core.drainEvents()) {
          if (e is RunEndedEvent) {
            expect(
              ended,
              isNull,
              reason: 'RunEndedEvent should be emitted once',
            );
            ended = e;
          }
        }
        if (core.gameOver) break;
      }

      expect(core.gameOver, isTrue);
      expect(core.paused, isTrue);
      expect(ended, isNotNull);
      expect(ended!.reason, RunEndReason.fellBehindCamera);

      // Further ticks do nothing.
      final tickAtEnd = core.tick;
      core.stepOneTick();
      expect(core.tick, tickAtEnd);

      final snap = core.buildSnapshot();
      expect(snap.gameOver, isTrue);
    },
    skip: const V0CameraTuning().speedLagMulX == 0.0
        ? 'Requires autoscroll (V0CameraTuning.speedLagMulX > 0)'
        : false,
  );
}
