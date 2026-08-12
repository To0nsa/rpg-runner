import 'package:runner_core/collision/static_world_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/characters/eloise_wip.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_data.dart';
import 'package:runner_core/track/staged_terrain_stream_candidate.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:test/test.dart';

const _stagedTerrainTestDigest =
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

void main() {
  test('normal construction keeps legacy spawn and integration behavior', () {
    final core = GameCore(
      seed: 7,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
    );

    expect(core.playerPosY, 276);
    expect(core.playerGrounded, isTrue);
    core.applyCommands(const [MoveAxisCommand(tick: 1, axis: 1)]);
    core.stepOneTick();
    expect(core.playerGrounded, isTrue);
    expect(core.distance, closeTo(core.playerVelX / 60, 1e-9));
  });

  test(
    'terrain harness spawns by support query and resolves actual movement',
    () {
      final core = GameCore.terrainMotionHarness(
        seed: 7,
        levelDefinition: _level(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrain(),
      );

      expect(core.playerGrounded, isTrue);
      expect(core.playerPosY, closeTo(275.9375, 3 / 1024));
      final startX = core.playerPosX;
      core.applyCommands(const [MoveAxisCommand(tick: 1, axis: 1)]);
      core.stepOneTick();

      expect(core.playerGrounded, isTrue);
      expect(core.playerPosX, greaterThan(startX));
      expect(core.distance, closeTo(core.playerPosX - startX, 1 / 1024));
    },
  );

  test(
    'staged stream candidate geometry drives the isolated terrain authority',
    () {
      final candidate = _stagedTerrainHarnessCandidate();
      final core = GameCore.terrainMotionHarness(
        seed: 71,
        levelDefinition: _level(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: candidate.geometry,
      );

      expect(candidate.renderSnapshot.polygons, hasLength(1));
      expect(core.playerGrounded, isTrue);
      final startX = core.playerPosX;
      core.applyCommands(const [MoveAxisCommand(tick: 1, axis: 1)]);
      core.stepOneTick();

      expect(core.playerGrounded, isTrue);
      expect(core.playerPosX, greaterThan(startX));
      expect(core.buildTerrainPlayerDebugSnapshot()!.geometryVersion, 1);
    },
  );

  test('terrain teleport and upward launch clear retained support', () {
    final core = GameCore.terrainMotionHarness(
      seed: 8,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
    );

    core.setPlayerPosXYUnsafeForTest(core.playerPosX, 240);
    expect(core.playerGrounded, isFalse);

    core.setPlayerVelXY(0, -100);
    core.applyCommands(const <Command>[]);
    core.stepOneTick();
    expect(core.playerGrounded, isFalse);
    expect(core.playerVelY, lessThan(0));
  });

  test(
    'queued terrain publishes before intent regardless of call ordering',
    () {
      GameCore build() => GameCore.terrainMotionHarness(
        seed: 81,
        levelDefinition: _level(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrain(),
      );

      final queuedFirst = build();
      queuedFirst.queueTerrainHarnessGeometryReplacement(_terrain(version: 2));
      queuedFirst.applyCommands(const [MoveAxisCommand(tick: 1, axis: 1)]);

      final inputFirst = build();
      inputFirst.applyCommands(const [MoveAxisCommand(tick: 1, axis: 1)]);
      inputFirst.queueTerrainHarnessGeometryReplacement(_terrain(version: 2));

      queuedFirst.stepOneTick();
      inputFirst.stepOneTick();
      final queuedDebug = queuedFirst.buildTerrainPlayerDebugSnapshot()!;
      final inputDebug = inputFirst.buildTerrainPlayerDebugSnapshot()!;

      expect(queuedDebug.geometryVersion, 2);
      expect(inputDebug.geometryVersion, 2);
      expect(queuedFirst.playerPosX, inputFirst.playerPosX);
      expect(queuedFirst.playerPosY, inputFirst.playerPosY);
      expect(queuedFirst.playerVelX, inputFirst.playerVelX);
      expect(queuedFirst.playerVelY, inputFirst.playerVelY);
      expect(queuedDebug.supportEdgeId, inputDebug.supportEdgeId);
      expect(queuedDebug.resolvedXTicks, inputDebug.resolvedXTicks);
      expect(queuedDebug.resolvedYTicks, inputDebug.resolvedYTicks);
    },
  );

  test('normal construction rejects terrain-harness replacement', () {
    final core = GameCore(
      seed: 82,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
    );

    expect(
      () => core.queueTerrainHarnessGeometryReplacement(_terrain(version: 2)),
      throwsStateError,
    );
  });

  test('terrain support applies the continuous signed slope target curve', () {
    final uphill = GameCore.terrainMotionHarness(
      seed: 9,
      levelDefinition: _level(groundTopY: 700),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _slopeTerrain(),
    );
    final downhill = GameCore.terrainMotionHarness(
      seed: 9,
      levelDefinition: _level(groundTopY: 700),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _slopeTerrain(),
    );

    _holdAxis(uphill, 1, ticks: 60);
    _holdAxis(downhill, -1, ticks: 60);

    // Éloïse's default loadout resolves to 95% move speed before terrain:
    // 190 * 85% uphill and 190 * 110% downhill at 45 degrees.
    expect(uphill.playerVelX, closeTo(161.5, 1 / 1024));
    expect(
      downhill.playerVelX,
      closeTo(-209, 1 / 1024),
      reason:
          'tick=${downhill.tick} gameOver=${downhill.gameOver} '
          'pos=(${downhill.playerPosX},${downhill.playerPosY})',
    );
    expect(uphill.playerGrounded, isTrue);
    expect(downhill.playerGrounded, isTrue);
  });

  test('jump clears support before its world-up impulse is resolved', () {
    final core = GameCore.terrainMotionHarness(
      seed: 10,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
    );
    final startY = core.playerPosY;

    core.applyCommands(const [JumpPressedCommand(tick: 1)]);
    core.stepOneTick();

    expect(core.playerGrounded, isFalse);
    expect(core.playerVelY, lessThan(0));
    expect(core.playerPosY, lessThan(startY));
  });

  test(
    'grounded vertical dash follows facing tangent, airborne dash does not',
    () {
      final grounded = GameCore.terrainMotionHarness(
        seed: 11,
        levelDefinition: _level(groundTopY: 700),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _slopeTerrain(),
      );
      final groundedStartX = grounded.playerPosX;
      final groundedStartY = grounded.playerPosY;
      grounded.applyCommands(const [
        AimDirCommand(tick: 1, x: 0, y: -1),
        DashPressedCommand(tick: 1),
      ]);
      grounded.stepOneTick();

      expect(grounded.playerGrounded, isTrue);
      expect(grounded.playerPosX, greaterThan(groundedStartX));
      expect(grounded.playerPosY, lessThan(groundedStartY));
      expect(grounded.playerVelX, greaterThan(0));
      expect(grounded.playerVelY, lessThan(0));

      final airborne = GameCore.terrainMotionHarness(
        seed: 12,
        levelDefinition: _level(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrain(),
      );
      airborne.setPlayerPosXYUnsafeForTest(airborne.playerPosX, 240);
      final airborneStartX = airborne.playerPosX;
      final airborneStartY = airborne.playerPosY;
      airborne.applyCommands(const [
        AimDirCommand(tick: 1, x: 0, y: -1),
        DashPressedCommand(tick: 1),
      ]);
      airborne.stepOneTick();

      expect(airborne.playerGrounded, isFalse);
      expect(airborne.playerPosX, closeTo(airborneStartX, 1 / 1024));
      expect(airborne.playerPosY, lessThan(airborneStartY));
      expect(airborne.playerVelX, closeTo(0, 1 / 1024));
      expect(airborne.playerVelY, lessThan(0));
    },
  );

  test(
    'terrain snapshots use final support and retain upright render state',
    () {
      final core = GameCore.terrainMotionHarness(
        seed: 13,
        levelDefinition: _level(groundTopY: 700),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _slopeTerrain(),
      );

      _holdAxis(core, 1, ticks: 60);
      final player = core.buildSnapshot().playerEntity!;

      expect(player.grounded, isTrue);
      expect(player.anim, isNot(anyOf(AnimKey.jump, AnimKey.fall)));
      expect(player.rotationRad, 0);
      expect(player.size!.x, 20.6);
      expect(player.size!.y, 46);
    },
  );

  test(
    'walk/run phase follows support distance and caps 60-degree downhill',
    () {
      final flat = GameCore.terrainMotionHarness(
        seed: 14,
        levelDefinition: _level(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrain(),
      );
      final uphill45 = GameCore.terrainMotionHarness(
        seed: 14,
        levelDefinition: _level(groundTopY: 700),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _slopeTerrain(),
      );
      final downhill60 = GameCore.terrainMotionHarness(
        seed: 14,
        levelDefinition: _level(
          groundTopY: 3000,
          killPlaneY: 4000,
          playerStartX: 600,
        ),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _downhill60Terrain(),
      );

      _holdAxis(flat, 1, ticks: 60);
      _holdAxis(uphill45, 1, ticks: 60);
      _holdAxis(downhill60, -1, ticks: 60);
      final flatStart = flat.buildSnapshot().playerEntity!.animFrame!;
      final uphillStart = uphill45.buildSnapshot().playerEntity!.animFrame!;
      final downhillStart = downhill60.buildSnapshot().playerEntity!.animFrame!;

      _holdAxis(flat, 1, ticks: 20);
      _holdAxis(uphill45, 1, ticks: 20);
      _holdAxis(downhill60, -1, ticks: 20);
      final flatDelta =
          flat.buildSnapshot().playerEntity!.animFrame! - flatStart;
      final uphillDelta =
          uphill45.buildSnapshot().playerEntity!.animFrame! - uphillStart;
      final downhillDelta =
          downhill60.buildSnapshot().playerEntity!.animFrame! - downhillStart;

      expect(flatDelta, 20);
      expect(uphillDelta, inInclusiveRange(23, 25));
      expect(downhillDelta, 30);
    },
  );

  test('blocked terrain movement does not advance locomotion phase', () {
    final core = GameCore.terrainMotionHarness(
      seed: 15,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _floorAndWallTerrain(),
    );
    _holdAxis(core, 1, ticks: 120);
    final before = core.buildTerrainPlayerDebugSnapshot()!;

    _holdAxis(core, 1, ticks: 20);
    final after = core.buildTerrainPlayerDebugSnapshot()!;

    expect(core.playerVelX, 0);
    expect(after.groundedLocomotionPhaseBp, before.groundedLocomotionPhaseBp);
  });

  test('terrain debug snapshot is on-demand, quantized, and immutable', () {
    final legacy = GameCore(
      seed: 16,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
    );
    expect(legacy.buildTerrainPlayerDebugSnapshot(), isNull);

    final terrain = GameCore.terrainMotionHarness(
      seed: 16,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
    );
    terrain.applyCommands(const [MoveAxisCommand(tick: 1, axis: 1)]);
    terrain.stepOneTick();
    final debug = terrain.buildTerrainPlayerDebugSnapshot()!;

    expect(debug.tick, 1);
    expect(debug.geometryVersion, 1);
    expect(debug.grounded, isTrue);
    expect(debug.supportEdgeId, isNotNull);
    expect(debug.capsuleRadiusTicks, 10547);
    expect(debug.capsuleVerticalHalfSegmentTicks, 13005);
    expect(debug.finalBodyXTicks, closeTo(terrain.playerPosX * 1024, 1));
    expect(debug.blockingContacts.clear, throwsUnsupportedError);
  });

  test(
    'absolute kill plane overrides the legacy ground-relative threshold',
    () {
      final legacyLevel = _level(groundTopY: 1000);
      expect(legacyLevel.resolveKillPlaneY(legacyGapOffsetY: 400), 1400);
      final absoluteLevel = _level(groundTopY: 1000, killPlaneY: 480);
      expect(absoluteLevel.resolveKillPlaneY(legacyGapOffsetY: 400), 480);

      final core = GameCore.terrainMotionHarness(
        seed: 17,
        levelDefinition: absoluteLevel,
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrainAtY1000(),
      );
      core.stepOneTick();
      expect(core.gameOver, isTrue);
    },
  );

  test(
    'coyote jump remains available after a natural terrain ledge departure',
    () {
      final core = GameCore.terrainMotionHarness(
        seed: 18,
        levelDefinition: _level(killPlaneY: 1000),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _shortLedgeTerrain(),
      );

      while (core.playerGrounded && core.tick < 30) {
        _holdAxis(core, 1, ticks: 1);
      }
      expect(core.playerGrounded, isFalse);
      final departure = core.buildTerrainPlayerDebugSnapshot()!;
      expect(departure.gravityYTicks, greaterThan(0));

      core.applyCommands([JumpPressedCommand(tick: core.tick + 1)]);
      core.stepOneTick();

      expect(core.playerVelY, lessThan(0));
      expect(core.playerGrounded, isFalse);
    },
  );

  test('buffered jump commits after terrain landing, not before it', () {
    final core = GameCore.terrainMotionHarness(
      seed: 19,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
    );
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, 250);
    core.setPlayerVelXY(0, 300);
    core.applyCommands(const [JumpPressedCommand(tick: 1)]);

    var launched = false;
    for (var index = 0; index < 8; index += 1) {
      core.stepOneTick();
      if (core.playerVelY < 0) {
        launched = true;
        break;
      }
    }

    expect(launched, isTrue);
    expect(core.playerGrounded, isFalse);
  });

  test('terrain harness preserves the authored air-jump path', () {
    final core = GameCore.terrainMotionHarness(
      seed: 20,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
      equippedLoadoutOverride: const EquippedLoadoutDef(
        abilityJumpId: 'eloise.double_jump',
      ),
    );
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, 220);
    final manaBefore = core.buildSnapshot().hud.mana;
    core.applyCommands(const [JumpPressedCommand(tick: 1)]);
    core.stepOneTick();

    expect(core.playerGrounded, isFalse);
    expect(core.playerVelY, lessThan(0));
    expect(core.buildSnapshot().hud.mana, lessThan(manaBefore));
  });

  test('external launch and knockback resolve against capsule blockers', () {
    final wall = GameCore.terrainMotionHarness(
      seed: 21,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _roomTerrain(),
    );
    wall.setPlayerVelXY(5000, 0);
    wall.stepOneTick();
    final wallDebug = wall.buildTerrainPlayerDebugSnapshot()!;
    expect(wallDebug.hitRight, isTrue);
    expect(wall.playerVelX, 0);

    final ceiling = GameCore.terrainMotionHarness(
      seed: 22,
      levelDefinition: _level(playerStartX: 200),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _roomTerrain(),
    );
    ceiling.setPlayerPosXYUnsafeForTest(300, ceiling.playerPosY);
    ceiling.setPlayerVelXY(0, -5000);
    ceiling.stepOneTick();
    final ceilingDebug = ceiling.buildTerrainPlayerDebugSnapshot()!;
    expect(
      ceilingDebug.hitCeiling,
      isTrue,
      reason:
          'pos=(${ceiling.playerPosX},${ceiling.playerPosY}) '
          'vel=(${ceiling.playerVelX},${ceiling.playerVelY}) '
          'diag=${ceilingDebug.diagnostic} '
          'contacts=${ceilingDebug.blockingContacts.length}',
    );
    expect(ceiling.playerVelY, 0);

    final landing = GameCore.terrainMotionHarness(
      seed: 23,
      levelDefinition: _level(playerStartX: 200),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _roomTerrain(),
    );
    landing.setPlayerPosXYUnsafeForTest(landing.playerPosX, 260);
    landing.setPlayerVelXY(0, 5000);
    landing.stepOneTick();
    expect(landing.playerGrounded, isTrue);
    expect(landing.playerVelY, 0);

    final dash = GameCore.terrainMotionHarness(
      seed: 230,
      levelDefinition: _level(playerStartX: 342),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _floorAndWallTerrain(),
    );
    dash.applyCommands(const [
      AimDirCommand(tick: 1, x: 1, y: 0),
      DashPressedCommand(tick: 1),
    ]);
    dash.stepOneTick();
    final dashDebug = dash.buildTerrainPlayerDebugSnapshot()!;
    expect(dashDebug.hitRight, isTrue);
    expect(
      dashDebug.capsuleCenterXTicks + dashDebug.capsuleRadiusTicks,
      lessThanOrEqualTo(360 * 1024 + terrainContactEpsilonTicks),
    );
  });

  test('airborne diagonal landing retains only slope-tangent velocity', () {
    final core = GameCore.terrainMotionHarness(
      seed: 231,
      levelDefinition: _level(groundTopY: 700, killPlaneY: 1200),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _slopeTerrain(),
    );
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, core.playerPosY - 10);
    core.setPlayerVelXY(300, 600);

    for (var tick = 0; tick < 10 && !core.playerGrounded; tick += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
    }

    expect(core.playerGrounded, isTrue);
    final debug = core.buildTerrainPlayerDebugSnapshot()!;
    expect(debug.finalVelocityXTicks.abs(), greaterThan(0));
    final normalVelocityDot =
        debug.finalVelocityXTicks * debug.supportNormalXTicks +
        debug.finalVelocityYTicks * debug.supportNormalYTicks;
    expect(
      normalVelocityDot.abs(),
      lessThanOrEqualTo(terrainDirectionScale * 2),
    );
  });

  test('grounded mobility preserves authored surface distance on a slope', () {
    final flat = GameCore.terrainMotionHarness(
      seed: 24,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
    );
    final slope = GameCore.terrainMotionHarness(
      seed: 24,
      levelDefinition: _level(groundTopY: 700),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _slopeTerrain(),
    );
    for (final core in [flat, slope]) {
      core.applyCommands(const [
        AimDirCommand(tick: 1, x: 0, y: -1),
        DashPressedCommand(tick: 1),
      ]);
      core.stepOneTick();
    }

    final flatTravel = flat
        .buildTerrainPlayerDebugSnapshot()!
        .supportedTravelTicks
        .abs();
    final slopeTravel = slope
        .buildTerrainPlayerDebugSnapshot()!
        .supportedTravelTicks
        .abs();
    expect(flatTravel, greaterThan(0));
    expect(slopeTravel, closeTo(flatTravel, 2));
  });

  test('Éloïse and Éloïse WIP share identical terrain traversal results', () {
    final cores = [eloiseCharacter, eloiseWipCharacter]
        .map(
          (character) => GameCore.terrainMotionHarness(
            seed: 25,
            levelDefinition: _level(groundTopY: 700),
            playerCharacter: character,
            terrainGeometry: _slopeTerrain(),
          ),
        )
        .toList();
    for (final core in cores) {
      _holdAxis(core, 1, ticks: 60);
    }
    final first = cores.first.buildTerrainPlayerDebugSnapshot()!;
    final second = cores.last.buildTerrainPlayerDebugSnapshot()!;

    expect(second.finalBodyXTicks, first.finalBodyXTicks);
    expect(second.finalBodyYTicks, first.finalBodyYTicks);
    expect(second.finalVelocityXTicks, first.finalVelocityXTicks);
    expect(second.finalVelocityYTicks, first.finalVelocityYTicks);
    expect(second.supportEdgeId, first.supportEdgeId);
    expect(second.supportedTravelTicks, first.supportedTravelTicks);
    expect(cores.last.distance, cores.first.distance);
  });

  test('SG-P01 through SG-P09 smoke matrix passes both player definitions', () {
    for (final character in [eloiseCharacter, eloiseWipCharacter]) {
      final label = character.id.name;

      final stationary = GameCore.terrainMotionHarness(
        seed: 251,
        levelDefinition: _level(),
        playerCharacter: character,
        terrainGeometry: _terrain(),
      );
      final stationaryStartX = stationary.playerPosX;
      final stationaryStartY = stationary.playerPosY;
      for (var tick = 0; tick < 180; tick += 1) {
        stationary.applyCommands(const <Command>[]);
        stationary.stepOneTick();
        expect(stationary.playerGrounded, isTrue, reason: '$label SG-P01');
      }
      expect(stationary.playerPosX, stationaryStartX, reason: '$label SG-P01');
      expect(stationary.playerPosY, stationaryStartY, reason: '$label SG-P01');

      final traverse = GameCore.terrainMotionHarness(
        seed: 252,
        levelDefinition: _level(
          groundTopY: 700,
          killPlaneY: 1200,
          playerStartX: 100,
        ),
        playerCharacter: character,
        terrainGeometry: _flatSlopeFlatTerrain(),
      );
      _holdAxisGrounded(traverse, 1, ticks: 180);
      _holdAxisGrounded(traverse, -1, ticks: 180);
      expect(traverse.playerGrounded, isTrue, reason: '$label SG-P02');

      final speed = GameCore.terrainMotionHarness(
        seed: 253,
        levelDefinition: _level(
          groundTopY: 1200,
          killPlaneY: 1800,
          playerStartX: 100,
        ),
        playerCharacter: character,
        terrainGeometry: _singleSlopeTerrain(
          shapeId: 'matrix-60',
          dx: 560,
          dy: -970,
        ),
      );
      _holdAxisGrounded(speed, 1, ticks: 60);
      expect(
        speed.playerVelX,
        closeTo(142.5, 1 / 1024),
        reason: '$label SG-P03',
      );

      final jump = GameCore.terrainMotionHarness(
        seed: 254,
        levelDefinition: _level(),
        playerCharacter: character,
        terrainGeometry: _terrain(),
        equippedLoadoutOverride: const EquippedLoadoutDef(
          abilityJumpId: 'eloise.double_jump',
        ),
      );
      jump.setPlayerPosXYUnsafeForTest(jump.playerPosX, jump.playerPosY - 30);
      jump.applyCommands(const [JumpPressedCommand(tick: 1)]);
      jump.stepOneTick();
      expect(jump.playerVelY, lessThan(0), reason: '$label SG-P04');

      final dash = GameCore.terrainMotionHarness(
        seed: 255,
        levelDefinition: _level(
          groundTopY: 304,
          killPlaneY: 1000,
          playerStartX: 311.5,
        ),
        playerCharacter: character,
        terrainGeometry: _mobilityStepTerrain(),
      );
      dash.applyCommands(const [
        AimDirCommand(tick: 1, x: 1, y: 0),
        DashPressedCommand(tick: 1),
      ]);
      dash.stepOneTick();
      expect(
        dash.buildTerrainPlayerDebugSnapshot()!.usedStep,
        isTrue,
        reason: '$label SG-P05',
      );

      final impact = GameCore.terrainMotionHarness(
        seed: 256,
        levelDefinition: _level(),
        playerCharacter: character,
        terrainGeometry: _roomTerrain(),
      );
      impact.setPlayerVelXY(5000, 0);
      impact.stepOneTick();
      expect(
        impact.buildTerrainPlayerDebugSnapshot()!.hitRight,
        isTrue,
        reason: '$label SG-P06',
      );

      final fall = GameCore.terrainMotionHarness(
        seed: 257,
        levelDefinition: _level(
          groundTopY: 1200,
          killPlaneY: 1800,
          playerStartX: 200,
        ),
        playerCharacter: character,
        terrainGeometry: _singleSlopeTerrain(
          shapeId: 'matrix-fall-60',
          dx: 560,
          dy: -970,
        ),
      );
      fall.setPlayerPosXYUnsafeForTest(fall.playerPosX, fall.playerPosY - 100);
      fall.setPlayerVelXY(0, 5000);
      for (var tick = 0; tick < 90 && !fall.playerGrounded; tick += 1) {
        fall.applyCommands(const <Command>[]);
        fall.stepOneTick();
      }
      expect(fall.playerGrounded, isTrue, reason: '$label SG-P07');

      final pit = GameCore.terrainMotionHarness(
        seed: 258,
        levelDefinition: _level(killPlaneY: 480),
        playerCharacter: character,
        terrainGeometry: _shortLedgeTerrain(),
      );
      while (pit.playerGrounded && pit.tick < 30) {
        _holdAxis(pit, 1, ticks: 1);
      }
      while (!pit.gameOver && pit.tick < 180) {
        pit.applyCommands(const <Command>[]);
        pit.stepOneTick();
      }
      expect(pit.gameOver, isTrue, reason: '$label SG-P08');

      final oneWay = GameCore.terrainMotionHarness(
        seed: 259,
        levelDefinition: _level(killPlaneY: 1200),
        playerCharacter: character,
        terrainGeometry: _oneWayTerrain(),
      );
      oneWay.setPlayerPosXYUnsafeForTest(oneWay.playerPosX, 340);
      oneWay.setPlayerVelXY(0, -1000);
      var crossedAbove = false;
      for (var tick = 0; tick < 120; tick += 1) {
        oneWay.applyCommands(const <Command>[]);
        oneWay.stepOneTick();
        if (oneWay.playerPosY < 276) crossedAbove = true;
        if (crossedAbove && oneWay.playerGrounded) break;
      }
      expect(crossedAbove, isTrue, reason: '$label SG-P09');
      expect(oneWay.playerGrounded, isTrue, reason: '$label SG-P09');
    }
  });

  test('flat-slope-flat traversal stays supported in both directions', () {
    final core = GameCore.terrainMotionHarness(
      seed: 26,
      levelDefinition: _level(
        groundTopY: 700,
        killPlaneY: 1200,
        playerStartX: 100,
      ),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _flatSlopeFlatTerrain(),
    );

    _holdAxisGrounded(core, 1, ticks: 180);
    expect(core.playerPosX, greaterThan(500));
    final rightDebug = core.buildTerrainPlayerDebugSnapshot()!;
    expect(rightDebug.hitLeft || rightDebug.hitRight, isFalse);

    _holdAxisGrounded(core, -1, ticks: 180);
    expect(core.playerPosX, lessThan(300));
    final leftDebug = core.buildTerrainPlayerDebugSnapshot()!;
    expect(leftDebug.hitLeft || leftDebug.hitRight, isFalse);
  });

  test('support transitions and exact seams never select an air animation', () {
    void traverse(GameCore core, double axis, int ticks) {
      for (var index = 0; index < ticks; index += 1) {
        core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: axis)]);
        core.stepOneTick();
        final player = core.buildSnapshot().playerEntity!;
        expect(core.playerGrounded, isTrue, reason: 'tick=${core.tick}');
        expect(
          player.anim,
          isNot(anyOf(AnimKey.jump, AnimKey.fall)),
          reason: 'tick=${core.tick}',
        );
      }
    }

    final transitions = GameCore.terrainMotionHarness(
      seed: 261,
      levelDefinition: _level(
        groundTopY: 700,
        killPlaneY: 1200,
        playerStartX: 100,
      ),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _flatSlopeFlatTerrain(),
    );
    traverse(transitions, 1, 180);
    traverse(transitions, -1, 180);

    final seam = GameCore.terrainMotionHarness(
      seed: 262,
      levelDefinition: _level(playerStartX: 280),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _stitchedFlatTerrain(),
    );
    traverse(seam, 1, 60);
    traverse(seam, -1, 60);
  });

  test('low, run, and maximum falls land on 30/45/60-degree support', () {
    for (final slope in <(String, double, double)>[
      ('30', 970, -560),
      ('45', 970, -970),
      ('60', 560, -970),
    ]) {
      for (final fallVelocity in <double>[300, 1000, 4000]) {
        final core = GameCore.terrainMotionHarness(
          seed: 27,
          levelDefinition: _level(
            groundTopY: 1200,
            killPlaneY: 1800,
            playerStartX: 200,
          ),
          playerCharacter: eloiseCharacter,
          terrainGeometry: _singleSlopeTerrain(
            shapeId: 'slope-${slope.$1}',
            dx: slope.$2,
            dy: slope.$3,
          ),
        );
        final supportedY = core.playerPosY;
        core.setPlayerPosXYUnsafeForTest(core.playerPosX, supportedY - 100);
        core.setPlayerVelXY(0, fallVelocity);

        var landed = false;
        for (var tick = 0; tick < 90 && !core.gameOver; tick += 1) {
          core.applyCommands(const <Command>[]);
          core.stepOneTick();
          if (core.playerGrounded) {
            landed = true;
            break;
          }
        }

        expect(
          landed,
          isTrue,
          reason: '${slope.$1} degrees at $fallVelocity units/s',
        );
        expect(
          core.buildTerrainPlayerDebugSnapshot()!.supportEdgeId,
          isNotNull,
          reason: '${slope.$1} degrees at $fallVelocity units/s',
        );
      }
    }
  });

  test('one-way terrain passes upward, then lands and traverses', () {
    final core = GameCore.terrainMotionHarness(
      seed: 28,
      levelDefinition: _level(killPlaneY: 1200),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _oneWayTerrain(),
    );
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, 340);
    core.setPlayerVelXY(0, -1000);

    var crossedAbove = false;
    for (var tick = 0; tick < 120; tick += 1) {
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
      final debug = core.buildTerrainPlayerDebugSnapshot()!;
      if (core.playerPosY < 276) crossedAbove = true;
      if (core.playerVelY < 0) {
        expect(core.playerGrounded, isFalse);
        expect(debug.hitCeiling, isFalse);
      }
      if (crossedAbove && core.playerGrounded) break;
    }

    expect(crossedAbove, isTrue);
    expect(core.playerGrounded, isTrue);
    final before = core.playerPosX;
    _holdAxisGrounded(core, 1, ticks: 30);
    expect(core.playerPosX, greaterThan(before));
    expect(core.buildTerrainPlayerDebugSnapshot()!.hitRight, isFalse);
  });

  test('60-degree surface travel keeps the accepted 150%/230% result', () {
    final flat = GameCore.terrainMotionHarness(
      seed: 29,
      levelDefinition: _level(
        groundTopY: 1200,
        killPlaneY: 1800,
        playerStartX: 300,
      ),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _flatTerrainAtY1200(),
    );
    final uphill = GameCore.terrainMotionHarness(
      seed: 29,
      levelDefinition: _level(
        groundTopY: 1200,
        killPlaneY: 1800,
        playerStartX: 100,
      ),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _singleSlopeTerrain(
        shapeId: 'uphill-60',
        dx: 560,
        dy: -970,
      ),
    );
    final downhill = GameCore.terrainMotionHarness(
      seed: 29,
      levelDefinition: _level(
        groundTopY: 1200,
        killPlaneY: 1800,
        playerStartX: 500,
      ),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _singleSlopeTerrain(
        shapeId: 'downhill-60',
        dx: 560,
        dy: -970,
      ),
    );

    _holdAxisGrounded(flat, 1, ticks: 60);
    _holdAxisGrounded(uphill, 1, ticks: 60);
    _holdAxisGrounded(downhill, -1, ticks: 60);
    expect(flat.playerVelX, closeTo(190, 1 / 1024));
    expect(uphill.playerVelX, closeTo(142.5, 1 / 1024));
    expect(downhill.playerVelX, closeTo(-218.5, 1 / 1024));

    _holdAxisGrounded(flat, 1, ticks: 1);
    _holdAxisGrounded(uphill, 1, ticks: 1);
    _holdAxisGrounded(downhill, -1, ticks: 1);
    final flatTravel = flat
        .buildTerrainPlayerDebugSnapshot()!
        .supportedTravelTicks
        .abs();
    final uphillTravel = uphill
        .buildTerrainPlayerDebugSnapshot()!
        .supportedTravelTicks
        .abs();
    final downhillTravel = downhill
        .buildTerrainPlayerDebugSnapshot()!
        .supportedTravelTicks
        .abs();
    expect(uphillTravel / flatTravel, closeTo(1.5, 0.01));
    expect(downhillTravel / flatTravel, closeTo(2.3, 0.01));
  });

  test('grounded dash may step while airborne-started dash may not', () {
    GameCore create(int seed) => GameCore.terrainMotionHarness(
      seed: seed,
      levelDefinition: _level(
        groundTopY: 304,
        killPlaneY: 1000,
        playerStartX: 311.5,
      ),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _mobilityStepTerrain(),
    );

    final grounded = create(30);
    grounded.applyCommands(const [
      AimDirCommand(tick: 1, x: 1, y: 0),
      DashPressedCommand(tick: 1),
    ]);
    grounded.stepOneTick();
    final groundedDebug = grounded.buildTerrainPlayerDebugSnapshot()!;
    expect(
      groundedDebug.usedStep,
      isTrue,
      reason:
          'pos=(${grounded.playerPosX},${grounded.playerPosY}) '
          'requested=(${groundedDebug.requestedXTicks},'
          '${groundedDebug.requestedYTicks}) '
          'resolved=(${groundedDebug.resolvedXTicks},'
          '${groundedDebug.resolvedYTicks}) '
          'contacts=${groundedDebug.blockingContacts.length} '
          'diagnostic=${groundedDebug.diagnostic}',
    );
    expect(grounded.playerGrounded, isTrue);

    final airborne = create(31);
    airborne.setPlayerPosXYUnsafeForTest(
      airborne.playerPosX,
      airborne.playerPosY - 1,
    );
    airborne.applyCommands(const [
      AimDirCommand(tick: 1, x: 1, y: 1),
      DashPressedCommand(tick: 1),
    ]);
    airborne.stepOneTick();
    final airborneDebug = airborne.buildTerrainPlayerDebugSnapshot()!;
    expect(airborneDebug.usedStep, isFalse);
  });

  test('facing offset reverses safely on support, wall, and one-way edge', () {
    final supported = GameCore.terrainMotionHarness(
      seed: 32,
      levelDefinition: _level(),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _terrain(),
    );
    final right = supported.buildTerrainPlayerDebugSnapshot()!;
    expect(right.capsuleCenterXTicks - right.finalBodyXTicks, -307);
    supported.playerFacing = Facing.left;
    supported.stepOneTick();
    final left = supported.buildTerrainPlayerDebugSnapshot()!;
    expect(left.capsuleCenterXTicks - left.finalBodyXTicks, 307);
    expect(left.grounded, isTrue);

    final wall = GameCore.terrainMotionHarness(
      seed: 33,
      levelDefinition: _level(playerStartX: 300),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _floorAndWallTerrain(),
    );
    _holdAxis(wall, 1, ticks: 120);
    wall.playerFacing = Facing.left;
    wall.stepOneTick();
    wall.playerFacing = Facing.right;
    wall.stepOneTick();
    final wallDebug = wall.buildTerrainPlayerDebugSnapshot()!;
    expect(wallDebug.grounded, isTrue);
    expect(
      wallDebug.capsuleCenterXTicks + wallDebug.capsuleRadiusTicks,
      lessThanOrEqualTo(360 * 1024 + terrainContactEpsilonTicks),
    );

    final oneWay = GameCore.terrainMotionHarness(
      seed: 34,
      levelDefinition: _level(playerStartX: 20),
      playerCharacter: eloiseCharacter,
      terrainGeometry: _oneWayTerrain(),
    );
    oneWay.playerFacing = Facing.left;
    oneWay.stepOneTick();
    final oneWayDebug = oneWay.buildTerrainPlayerDebugSnapshot()!;
    expect(oneWayDebug.grounded, isTrue);
    expect(oneWayDebug.hitLeft || oneWayDebug.hitRight, isFalse);
    expect(oneWayDebug.capsuleCenterXTicks - oneWayDebug.finalBodyXTicks, 307);
  });

  test(
    'locked-Y camera stays fixed through slope, step, jump, and pit motion',
    () {
      final slope = GameCore.terrainMotionHarness(
        seed: 35,
        levelDefinition: _level(
          groundTopY: 700,
          killPlaneY: 1200,
          playerStartX: 300,
        ),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _slopeTerrain(),
      );
      final lockedY = slope.buildSnapshot().camera.centerY;
      _holdAxisGrounded(slope, 1, ticks: 30);
      expect(slope.buildSnapshot().camera.centerY, lockedY);

      final step = GameCore.terrainMotionHarness(
        seed: 36,
        levelDefinition: _level(
          groundTopY: 304,
          killPlaneY: 1000,
          playerStartX: 311.5,
        ),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _mobilityStepTerrain(),
      );
      final stepCameraY = step.buildSnapshot().camera.centerY;
      step.applyCommands(const [
        AimDirCommand(tick: 1, x: 1, y: 0),
        DashPressedCommand(tick: 1),
      ]);
      step.stepOneTick();
      expect(step.buildTerrainPlayerDebugSnapshot()!.usedStep, isTrue);
      expect(step.buildSnapshot().camera.centerY, stepCameraY);

      final jump = GameCore.terrainMotionHarness(
        seed: 37,
        levelDefinition: _level(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrain(),
      );
      final jumpCameraY = jump.buildSnapshot().camera.centerY;
      jump.applyCommands(const [JumpPressedCommand(tick: 1)]);
      jump.stepOneTick();
      for (var tick = 0; tick < 15; tick += 1) {
        jump.applyCommands(const <Command>[]);
        jump.stepOneTick();
      }
      expect(jump.playerPosY, lessThan(276));
      expect(jump.buildSnapshot().camera.centerY, jumpCameraY);

      final pit = GameCore.terrainMotionHarness(
        seed: 38,
        levelDefinition: _level(killPlaneY: 1000),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _shortLedgeTerrain(),
      );
      final pitCameraY = pit.buildSnapshot().camera.centerY;
      while (pit.playerGrounded && pit.tick < 30) {
        _holdAxis(pit, 1, ticks: 1);
      }
      for (var tick = 0; tick < 15; tick += 1) {
        pit.applyCommands(const <Command>[]);
        pit.stepOneTick();
      }
      expect(pit.playerPosY, greaterThan(276));
      expect(pit.buildSnapshot().camera.centerY, pitCameraY);
    },
  );

  test(
    'follow-player camera consumes slope, step, snap, jump, and pit results',
    () {
      LevelDefinition followLevel({
        double groundTopY = 300,
        double killPlaneY = 1000,
        double playerStartX = 300,
        double cameraCenterY = 276,
      }) => _level(
        groundTopY: groundTopY,
        killPlaneY: killPlaneY,
        playerStartX: playerStartX,
        cameraCenterY: cameraCenterY,
        cameraVerticalMode: CameraVerticalMode.followPlayer,
      );

      final slope = GameCore.terrainMotionHarness(
        seed: 39,
        levelDefinition: followLevel(
          groundTopY: 700,
          killPlaneY: 1200,
          cameraCenterY: 376,
        ),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _slopeTerrain(),
      );
      final slopeStartY = slope.buildSnapshot().camera.centerY;
      _holdAxisGrounded(slope, 1, ticks: 45);
      expect(slope.buildSnapshot().camera.centerY, lessThan(slopeStartY));

      final step = GameCore.terrainMotionHarness(
        seed: 40,
        levelDefinition: followLevel(
          groundTopY: 304,
          playerStartX: 311.5,
          cameraCenterY: 280,
        ),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _mobilityStepTerrain(),
      );
      final stepStartY = step.buildSnapshot().camera.centerY;
      step.applyCommands(const [
        AimDirCommand(tick: 1, x: 1, y: 0),
        DashPressedCommand(tick: 1),
      ]);
      step.stepOneTick();
      expect(step.buildTerrainPlayerDebugSnapshot()!.usedStep, isTrue);
      for (var tick = 0; tick < 10; tick += 1) {
        step.applyCommands(const <Command>[]);
        step.stepOneTick();
      }
      expect(step.buildSnapshot().camera.centerY, lessThan(stepStartY));

      final snap = GameCore.terrainMotionHarness(
        seed: 41,
        levelDefinition: followLevel(playerStartX: 300),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _threePixelDropTerrain(),
      );
      final snapStartY = snap.buildSnapshot().camera.centerY;
      var usedSnap = false;
      for (var tick = 0; tick < 40 && !usedSnap; tick += 1) {
        _holdAxisGrounded(snap, 1, ticks: 1);
        usedSnap = snap.buildTerrainPlayerDebugSnapshot()!.usedSnap;
      }
      expect(usedSnap, isTrue);
      for (var tick = 0; tick < 10; tick += 1) {
        _holdAxisGrounded(snap, 1, ticks: 1);
      }
      expect(snap.buildSnapshot().camera.centerY, greaterThan(snapStartY));

      final jump = GameCore.terrainMotionHarness(
        seed: 42,
        levelDefinition: followLevel(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _terrain(),
      );
      final jumpStartY = jump.buildSnapshot().camera.centerY;
      jump.applyCommands(const [JumpPressedCommand(tick: 1)]);
      jump.stepOneTick();
      for (var tick = 0; tick < 15; tick += 1) {
        jump.applyCommands(const <Command>[]);
        jump.stepOneTick();
      }
      expect(jump.buildSnapshot().camera.centerY, lessThan(jumpStartY));

      final pit = GameCore.terrainMotionHarness(
        seed: 43,
        levelDefinition: followLevel(),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _shortLedgeTerrain(),
      );
      final pitStartY = pit.buildSnapshot().camera.centerY;
      while (pit.playerGrounded && pit.tick < 30) {
        _holdAxis(pit, 1, ticks: 1);
      }
      for (var tick = 0; tick < 20; tick += 1) {
        pit.applyCommands(const <Command>[]);
        pit.stepOneTick();
      }
      expect(pit.buildSnapshot().camera.centerY, greaterThan(pitStartY));
    },
  );
}

void _holdAxis(GameCore core, double axis, {required int ticks}) {
  for (var index = 0; index < ticks; index += 1) {
    final before = core.playerPosX;
    core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: axis)]);
    core.stepOneTick();
    if ((core.playerPosX - before).abs() > 5) {
      fail(
        'Unexpected displacement at tick ${core.tick}: '
        '$before -> ${core.playerPosX}, velocity=${core.playerVelX}',
      );
    }
  }
}

void _holdAxisGrounded(GameCore core, double axis, {required int ticks}) {
  for (var index = 0; index < ticks; index += 1) {
    core.applyCommands([MoveAxisCommand(tick: core.tick + 1, axis: axis)]);
    core.stepOneTick();
    expect(
      core.playerGrounded,
      isTrue,
      reason:
          'Lost support at tick ${core.tick}, '
          'pos=(${core.playerPosX},${core.playerPosY})',
    );
  }
}

LevelDefinition _level({
  double groundTopY = 300,
  double? killPlaneY,
  double playerStartX = 300,
  double cameraCenterY = 135,
  CameraVerticalMode cameraVerticalMode = CameraVerticalMode.lockY,
}) => LevelDefinition(
  id: LevelId.field,
  chunkPatternSource: const ChunkPatternListSource(easyPatterns: []),
  cameraCenterY: cameraCenterY,
  staticWorldGeometry: StaticWorldGeometry(
    groundPlane: StaticGroundPlane(topY: groundTopY),
  ),
  tuning: CoreTuning(
    camera: CameraTuning(
      speedLagMulX: 0,
      followThresholdRatio: 1,
      verticalMode: cameraVerticalMode,
      verticalCatchupLerp: 20,
      verticalTargetCatchupLerp: 20,
      verticalDeadZone: 0,
    ),
    track: TrackTuning(enabled: false, playerStartX: playerStartX),
  ),
  killPlaneY: killPlaneY,
);

TerrainGeometry _terrain({int version = 1}) => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/ground',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'ground',
    ),
    vertices: [(0, 300), (1000, 300), (1000, 500), (0, 500)],
  ),
], geometryVersion: version);

StagedTerrainStreamCandidate _stagedTerrainHarnessCandidate() {
  const chunkKey = 'terrain_harness';
  final sourceId = StagedTerrainSourceId(chunkKey: chunkKey, shapeId: 'ground');
  final catalog = StagedTerrainArtifactCatalog(
    artifact: StagedTerrainArtifactData(
      formatVersion: stagedTerrainArtifactFormatVersion,
      compilerGeometryVersion: 1,
      authoringPolygonSignatureFormat: 'authoring-polygons-v1',
      authoringSeamSignatureFormat: 'authoring-seams-v1',
      authoringSeamSignature: _stagedTerrainTestDigest,
      sourceSignatureFormat: 'source-v1',
      edgeSignatureFormat: 'edges-v1',
      placementSignatureFormat: 'authoring-placement-v1',
      triangleSignatureFormat: 'authoring-triangles-v1',
      chunks: <StagedTerrainChunkData>[
        StagedTerrainChunkData(
          chunkKey: chunkKey,
          id: chunkKey,
          revision: 1,
          status: 'active',
          levelId: 'field',
          tileSize: 16,
          width: 600,
          height: 270,
          difficulty: 'normal',
          assemblyGroupId: 'default',
          authoringPolygonSignature: _stagedTerrainTestDigest,
          sourceSignature: _stagedTerrainTestDigest,
          edgeSignature: _stagedTerrainTestDigest,
          placementSignature: _stagedTerrainTestDigest,
          triangleSignature: _stagedTerrainTestDigest,
          polygons: <StagedTerrainPolygonData>[
            StagedTerrainPolygonData(
              sourcePath: 'test/staged-terrain-harness#ground',
              id: sourceId,
              sourceVertices: const <StagedTerrainPoint>[
                StagedTerrainPoint(0, 600),
                StagedTerrainPoint(1200, 600),
                StagedTerrainPoint(1200, 1000),
                StagedTerrainPoint(0, 1000),
              ],
              vertices: const <StagedTerrainPoint>[
                StagedTerrainPoint(0, 307200),
                StagedTerrainPoint(614400, 307200),
                StagedTerrainPoint(614400, 512000),
                StagedTerrainPoint(0, 512000),
              ],
              collisionMode: StagedTerrainCollisionMode.solid,
              surfaceKind: 'ground',
              materialKey: 'earth',
            ),
          ],
          edges: <StagedTerrainEdgeData>[
            StagedTerrainEdgeData(
              id: StagedTerrainEdgeId(
                sourceId: sourceId,
                localEdgeIndex: 0,
                subEdgeIndex: 0,
              ),
              start: const StagedTerrainPoint(0, 307200),
              end: const StagedTerrainPoint(614400, 307200),
              tangent: const StagedTerrainPoint(1024, 0),
              outwardNormal: const StagedTerrainPoint(0, -1024),
              collisionMode: StagedTerrainCollisionMode.solid,
              surfaceKind: 'ground',
              materialKey: 'earth',
              previousId: null,
              nextId: null,
              startJoin: StagedTerrainVertexJoin.exposed,
              endJoin: StagedTerrainVertexJoin.exposed,
            ),
          ],
          triangles: <StagedTerrainTriangleData>[
            StagedTerrainTriangleData(
              sourceId: sourceId,
              first: 0,
              second: 1,
              third: 2,
            ),
            StagedTerrainTriangleData(
              sourceId: sourceId,
              first: 0,
              second: 2,
              third: 3,
            ),
          ],
          placementLineage: const <StagedTerrainPlacementLineageData>[],
        ),
      ],
    ),
  );
  return const StagedTerrainStreamCandidateBuilder().build(
    catalog: catalog,
    activeChunks: const <ActiveTrackChunkSnapshot>[
      ActiveTrackChunkSnapshot(
        index: 0,
        startX: 0,
        endX: 600,
        patternName: chunkKey,
        chunkKey: chunkKey,
      ),
    ],
    geometryVersion: 1,
    groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
  );
}

TerrainGeometry _slopeTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/slope',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'slope',
    ),
    vertices: [(0, 700), (1000, -300), (1000, 900), (0, 900)],
  ),
], geometryVersion: 1);

TerrainGeometry _downhill60Terrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/downhill-60',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'downhill-60',
    ),
    vertices: [(0, 3000), (1120, 1060), (1400, 3600), (0, 3600)],
  ),
], geometryVersion: 1);

TerrainGeometry _floorAndWallTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/floor-and-wall',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'floor-and-wall',
    ),
    vertices: [
      (0, 300),
      (360, 300),
      (360, 100),
      (400, 100),
      (400, 500),
      (0, 500),
    ],
  ),
], geometryVersion: 1);

TerrainGeometry _terrainAtY1000() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/ground',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'ground',
    ),
    vertices: [(0, 1000), (1000, 1000), (1000, 1500), (0, 1500)],
  ),
], geometryVersion: 1);

TerrainGeometry _flatTerrainAtY1200() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/flat-1200',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'flat-1200',
    ),
    vertices: [(0, 1200), (1000, 1200), (1000, 1500), (0, 1500)],
  ),
], geometryVersion: 1);

TerrainGeometry _shortLedgeTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/short-ledge',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'short-ledge',
    ),
    vertices: [(0, 300), (340, 300), (340, 500), (0, 500)],
  ),
], geometryVersion: 1);

TerrainGeometry _roomTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/floor',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'floor',
    ),
    vertices: [(0, 300), (500, 300), (500, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/wall',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'wall',
    ),
    vertices: [(330, 150), (350, 150), (350, 300), (330, 300)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/ceiling',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'ceiling',
    ),
    vertices: [(250, 230), (330, 230), (330, 250), (250, 250)],
  ),
], geometryVersion: 1);

TerrainGeometry _flatSlopeFlatTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/flat-slope-flat',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'flat-slope-flat',
    ),
    vertices: [
      (0, 400),
      (200, 400),
      (400, 300),
      (900, 300),
      (900, 800),
      (0, 800),
    ],
  ),
], geometryVersion: 1);

TerrainGeometry _stitchedFlatTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/stitched-left',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'left',
      shapeId: 'ground',
    ),
    vertices: [(0, 300), (320, 300), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/stitched-right',
    identity: TerrainSourceIdentity(
      chunkIndex: 1,
      chunkKey: 'right',
      shapeId: 'ground',
    ),
    vertices: [(320, 300), (700, 300), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

TerrainGeometry _singleSlopeTerrain({
  required String shapeId,
  required double dx,
  required double dy,
}) => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/single-slope',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: shapeId,
    ),
    vertices: [(0, 1200), (dx, 1200 + dy), (dx + 300, 1500), (0, 1500)],
  ),
], geometryVersion: 1);

TerrainGeometry _oneWayTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/one-way',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'one-way',
    ),
    collisionMode: TerrainCollisionMode.oneWay,
    vertices: [(0, 300), (1000, 300), (1000, 310), (0, 310)],
  ),
], geometryVersion: 1);

TerrainGeometry _mobilityStepTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/lower-step',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'lower-step',
    ),
    vertices: [(0, 304), (320, 304), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/upper-step',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'upper-step',
    ),
    vertices: [(320, 301), (700, 301), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);

TerrainGeometry _threePixelDropTerrain() => const TerrainCompiler().compile([
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/high-drop',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'high-drop',
    ),
    vertices: [(0, 300), (320, 300), (320, 500), (0, 500)],
  ),
  TerrainPolygonInput.fromWorld(
    sourcePath: 'test/low-drop',
    identity: TerrainSourceIdentity(
      chunkIndex: 0,
      chunkKey: 'test',
      shapeId: 'low-drop',
    ),
    vertices: [(320, 303), (700, 303), (700, 500), (320, 500)],
  ),
], geometryVersion: 1);
