import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/camera/autoscroll_camera.dart';
import 'package:rpg_runner/core/contracts/render_contract.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/events/game_event.dart';
import 'package:rpg_runner/core/game_core.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/levels/level_registry.dart';
import 'package:rpg_runner/core/levels/level_world_constants.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/tuning/camera_tuning.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';

import '../support/test_player.dart';

void main() {
  CameraTuningDerived derived(CameraTuning tuning) {
    final movement = MovementTuningDerived.from(
      const MovementTuning(),
      tickHz: 60,
    );
    return CameraTuningDerived.from(tuning, movement: movement);
  }

  test('AutoscrollCamera: player past threshold pulls target forward', () {
    final tuning = derived(const CameraTuning());

    final cam = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
      tuning: tuning,
      initial: CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        centerY: defaultLevelCameraCenterY,
        targetY: defaultLevelCameraCenterY,
        speedX: 0.0,
      ),
    );

    final baselineTargetX = cam.state.targetX;

    // Player is far ahead, beyond the follow threshold.
    cam.updateTick(dtSeconds: 1.0 / 60.0, playerRightX: 2000.0, playerY: null);
    expect(cam.state.targetX, greaterThan(baselineTargetX));
    expect(cam.state.centerX, greaterThanOrEqualTo(virtualWidth * 0.5));
    expect(cam.state.centerY, defaultLevelCameraCenterY);
  });

  test('AutoscrollCamera invariants: centerX and targetX never decrease', () {
    final cam = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
      tuning: derived(
        const CameraTuning(
          speedLagMulX: 0.7,
          accelX: 240.0,
          followThresholdRatio: 0.55,
        ),
      ),
      initial: CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        centerY: defaultLevelCameraCenterY,
        targetY: defaultLevelCameraCenterY,
        speedX: 0.0,
      ),
    );

    var prevCenter = cam.state.centerX;
    var prevTarget = cam.state.targetX;

    for (var i = 0; i < 240; i += 1) {
      final playerRightX = i.isEven ? 2400.0 : null;
      cam.updateTick(
        dtSeconds: 1.0 / 60.0,
        playerRightX: playerRightX,
        playerY: null,
      );
      expect(cam.state.centerX, greaterThanOrEqualTo(prevCenter));
      expect(cam.state.targetX, greaterThanOrEqualTo(prevTarget));
      prevCenter = cam.state.centerX;
      prevTarget = cam.state.targetX;
    }
  });

  test('AutoscrollCamera invariants: speedX eases toward target speed', () {
    final tuning = derived(
      const CameraTuning(speedLagMulX: 0.8, accelX: 180.0),
    );

    final cam = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
      tuning: tuning,
      initial: CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        centerY: defaultLevelCameraCenterY,
        targetY: defaultLevelCameraCenterY,
        speedX: 0.0,
      ),
    );

    var prevSpeed = cam.state.speedX;
    for (var i = 0; i < 120; i += 1) {
      cam.updateTick(dtSeconds: 1.0 / 60.0, playerRightX: null, playerY: null);
      expect(cam.state.speedX, greaterThanOrEqualTo(prevSpeed));
      expect(cam.state.speedX, lessThanOrEqualTo(tuning.targetSpeedX));
      prevSpeed = cam.state.speedX;
    }
    expect(cam.state.speedX, closeTo(tuning.targetSpeedX, 1e-9));
  });

  test('AutoscrollCamera invariant: pull-forward is strict past threshold', () {
    final cam = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
      tuning: derived(
        const CameraTuning(speedLagMulX: 0.0, followThresholdRatio: 0.5),
      ),
      initial: CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        centerY: defaultLevelCameraCenterY,
        targetY: defaultLevelCameraCenterY,
        speedX: 0.0,
      ),
    );

    final baselineTarget = cam.state.targetX;
    final threshold = cam.followThresholdX();

    cam.updateTick(
      dtSeconds: 1.0 / 60.0,
      playerRightX: threshold,
      playerY: null,
    );
    expect(cam.state.targetX, closeTo(baselineTarget, 1e-12));

    cam.updateTick(
      dtSeconds: 1.0 / 60.0,
      playerRightX: threshold + 0.001,
      playerY: null,
    );
    expect(cam.state.targetX, greaterThan(baselineTarget));
  });

  test(
    'GameCore: falling behind camera ends run and emits RunEndedEvent once',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        levelDefinition: LevelRegistry.byId(LevelId.field),
        seed: 1,
        tickHz: 20,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
          ),
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
    skip: const CameraTuning().speedLagMulX == 0.0
        ? 'Requires autoscroll (CameraTuning.speedLagMulX > 0)'
        : false,
  );
}
