import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/collision/static_world_geometry.dart';
import 'package:rpg_runner/core/levels/level_definition.dart';
import 'package:rpg_runner/core/levels/level_id.dart';
import 'package:rpg_runner/core/levels/level_registry.dart';
import 'package:rpg_runner/core/game_core.dart';
import '../support/test_level.dart';
import 'package:rpg_runner/core/commands/command.dart';
import 'package:rpg_runner/core/tuning/core_tuning.dart';
import 'package:rpg_runner/core/tuning/track_tuning.dart';

import '../test_tunings.dart';

void main() {
  test('level definition derives groundTopY from static ground plane', () {
    final level = LevelDefinition(
      id: LevelId.field,
      patternPool: defaultPatternPool,
      cameraCenterY: 120,
      staticWorldGeometry: const StaticWorldGeometry(
        groundPlane: StaticGroundPlane(topY: 210),
      ),
    );

    expect(level.groundTopY, 210);
  });

  test('level definition requires a non-null ground plane', () {
    expect(
      () => LevelDefinition(
        id: LevelId.field,
        patternPool: defaultPatternPool,
        staticWorldGeometry: const StaticWorldGeometry(),
      ),
      throwsA(anyOf(isA<AssertionError>(), isA<StateError>())),
    );
  });

  test(
    'changing level-authored ground/camera values moves snapshot framing',
    () {
      const customGroundTopY = 212.0;
      const customCameraCenterY = 118.0;
      final level = LevelDefinition(
        id: LevelId.field,
        patternPool: defaultPatternPool,
        cameraCenterY: customCameraCenterY,
        staticWorldGeometry: const StaticWorldGeometry(
          groundPlane: StaticGroundPlane(topY: customGroundTopY),
        ),
        tuning: CoreTuning(
          camera: noAutoscrollCameraTuning,
          track: TrackTuning(enabled: false),
        ),
      );

      final core = GameCore(
        seed: 7,
        levelDefinition: level,
        playerCharacter: testPlayerCharacter,
      );
      final snapshot = core.buildSnapshot();

      expect(core.staticWorldGeometry.groundPlane, isNotNull);
      expect(core.staticWorldGeometry.groundPlane!.topY, customGroundTopY);
      expect(level.groundTopY, customGroundTopY);
      expect(snapshot.groundSurfaces, isNotEmpty);
      expect(snapshot.groundSurfaces.first.topY, customGroundTopY);
      expect(snapshot.camera.centerY, customCameraCenterY);
    },
  );

  test('themeId changes do not affect collision or geometry framing', () {
    const groundTopY = 214.0;
    const cameraCenterY = 122.0;
    const geometry = StaticWorldGeometry(
      groundPlane: StaticGroundPlane(topY: groundTopY),
    );
    final fieldTheme = LevelDefinition(
      id: LevelId.field,
      patternPool: defaultPatternPool,
      cameraCenterY: cameraCenterY,
      staticWorldGeometry: geometry,
      themeId: 'field',
      tuning: const CoreTuning(
        camera: noAutoscrollCameraTuning,
        track: TrackTuning(enabled: false),
      ),
    );
    final forestTheme = LevelDefinition(
      id: LevelId.field,
      patternPool: defaultPatternPool,
      cameraCenterY: cameraCenterY,
      staticWorldGeometry: geometry,
      themeId: 'forest',
      tuning: const CoreTuning(
        camera: noAutoscrollCameraTuning,
        track: TrackTuning(enabled: false),
      ),
    );

    final a = GameCore(
      seed: 11,
      levelDefinition: fieldTheme,
      playerCharacter: testPlayerCharacter,
    );
    final b = GameCore(
      seed: 11,
      levelDefinition: forestTheme,
      playerCharacter: testPlayerCharacter,
    );

    const ticks = 60;
    for (var t = 1; t <= ticks; t += 1) {
      final commands = <Command>[MoveAxisCommand(tick: t, axis: 1.0)];
      if (t == 20) commands.add(const JumpPressedCommand(tick: 20));
      a.applyCommands(commands);
      b.applyCommands(commands);
      a.stepOneTick();
      b.stepOneTick();
    }

    final sa = a.buildSnapshot();
    final sb = b.buildSnapshot();
    expect(sa.themeId, 'field');
    expect(sb.themeId, 'forest');
    expect(sa.groundSurfaces.length, sb.groundSurfaces.length);
    for (var i = 0; i < sa.groundSurfaces.length; i += 1) {
      expect(sa.groundSurfaces[i].minX, sb.groundSurfaces[i].minX);
      expect(sa.groundSurfaces[i].maxX, sb.groundSurfaces[i].maxX);
      expect(sa.groundSurfaces[i].topY, sb.groundSurfaces[i].topY);
    }
    expect(a.playerPosX, closeTo(b.playerPosX, 1e-9));
    expect(a.playerPosY, closeTo(b.playerPosY, 1e-9));
    expect(a.playerVelX, closeTo(b.playerVelX, 1e-9));
    expect(a.playerVelY, closeTo(b.playerVelY, 1e-9));
    expect(sa.camera.centerY, sb.camera.centerY);
    expect(sa.camera.centerY, cameraCenterY);
  });
}
