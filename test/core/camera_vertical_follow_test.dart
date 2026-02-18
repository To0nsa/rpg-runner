import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/camera/autoscroll_camera.dart';
import 'package:rpg_runner/core/contracts/render_contract.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/levels/level_definition.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/levels/level_registry.dart';
import 'package:rpg_runner/core/levels/level_world_constants.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/tuning/camera_tuning.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

CameraTuningDerived _derived(CameraTuning tuning) {
  final movement = MovementTuningDerived.from(
    const MovementTuning(),
    tickHz: defaultTickHz,
  );
  return CameraTuningDerived.from(tuning, movement: movement);
}

void main() {
  test('lockY mode keeps camera Y fixed', () {
    final cam = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
      tuning: _derived(
        const CameraTuning(
          speedLagMulX: 0.0,
          verticalMode: CameraVerticalMode.lockY,
        ),
      ),
      initial: const CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        centerY: defaultLevelCameraCenterY,
        targetY: defaultLevelCameraCenterY,
        speedX: 0.0,
      ),
    );

    for (var i = 0; i < 60; i += 1) {
      cam.updateTick(
        dtSeconds: 1.0 / defaultTickHz,
        playerRightX: null,
        playerY: 40.0,
      );
    }

    expect(cam.state.centerY, closeTo(defaultLevelCameraCenterY, 1e-9));
    expect(cam.state.targetY, closeTo(defaultLevelCameraCenterY, 1e-9));
  });

  test('followPlayer mode converges camera Y toward player with dead-zone', () {
    const initialY = 135.0;
    final cam = AutoscrollCamera(
      viewWidth: virtualWidth.toDouble(),
      viewHeight: virtualHeight.toDouble(),
      tuning: _derived(
        const CameraTuning(
          speedLagMulX: 0.0,
          verticalMode: CameraVerticalMode.followPlayer,
          verticalDeadZone: 4.0,
          verticalCatchupLerp: 10.0,
          verticalTargetCatchupLerp: 10.0,
        ),
      ),
      initial: const CameraState(
        centerX: virtualWidth * 0.5,
        targetX: virtualWidth * 0.5,
        centerY: initialY,
        targetY: initialY,
        speedX: 0.0,
      ),
    );

    for (var i = 0; i < 120; i += 1) {
      cam.updateTick(
        dtSeconds: 1.0 / defaultTickHz,
        playerRightX: null,
        playerY: 80.0,
      );
    }

    expect(cam.state.centerY, lessThan(initialY));
    expect(cam.state.targetY, closeTo(84.0, 0.5));
    expect(cam.top(), closeTo(cam.state.centerY - virtualHeight * 0.5, 1e-9));
    expect(
      cam.bottom(),
      closeTo(cam.state.centerY + virtualHeight * 0.5, 1e-9),
    );
  });

  test(
    'GameCore supports vertical follow mode without changing default levels',
    () {
      const followCamera = CameraTuning(
        speedLagMulX: 0.0,
        verticalMode: CameraVerticalMode.followPlayer,
        verticalDeadZone: 0.0,
        verticalCatchupLerp: 12.0,
        verticalTargetCatchupLerp: 12.0,
      );
      final baseLevel = LevelRegistry.byId(LevelId.field);
      final level = LevelDefinition(
        id: baseLevel.id,
        patternPool: baseLevel.patternPool,
        cameraCenterY: baseLevel.cameraCenterY,
        staticWorldGeometry: baseLevel.staticWorldGeometry,
        earlyPatternChunks: baseLevel.earlyPatternChunks,
        noEnemyChunks: baseLevel.noEnemyChunks,
        themeId: baseLevel.themeId,
        tuning: const CoreTuning(
          camera: followCamera,
          track: TrackTuning(enabled: false),
        ),
      );
      final core = GameCore(
        seed: 9,
        levelDefinition: level,
        playerCharacter: testPlayerCharacter,
      );

      final startY = core.buildSnapshot().camera.centerY;

      // Move the player well above the baseline so vertical follow has work.
      for (var i = 0; i < 30; i += 1) {
        core.setPlayerPosXY(core.playerPosX, 80.0);
        core.setPlayerVelXY(0.0, 0.0);
        core.stepOneTick();
      }
      final followedY = core.buildSnapshot().camera.centerY;

      expect(startY, closeTo(baseLevel.cameraCenterY, 1e-9));
      expect(followedY, lessThan(startY));
    },
  );
}
