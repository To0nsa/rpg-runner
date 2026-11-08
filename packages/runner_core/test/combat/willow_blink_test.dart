import 'package:test/test.dart';
import 'package:runner_core/abilities/catalog/bounty_hunter_ability_defs.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/staged_authored_terrain.dart';
import 'package:runner_core/track/staged_terrain_catalog.dart';
import 'package:runner_core/track/staged_terrain_world_geometry.dart';
import 'package:runner_core/tuning/camera_tuning.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:runner_core/weapons/weapon_id.dart';

void main() {
  final catalog = StagedTerrainArtifactCatalog(artifact: stagedAuthoredTerrain);
  final actual = const StagedTerrainWorldGeometryBuilder().build(
    bindings: [
      catalog.bind(
        chunkKey: 'forest_woodcamp_easy_003',
        chunkIndex: 0,
        worldOriginXTicks: 0,
      ),
    ],
    geometryVersion: 1,
  );
  final tent = actual.polygons.singleWhere(
    (p) => p.identity.placementKey?.contains('woods_tent_02') == true,
  );
  final left = tent.bounds.minX / 1024, right = tent.bounds.maxX / 1024;

  test('limit matches scaled placed tent collision, not image dimensions', () {
    final maxWidth = bountyHunterAbilityDefs['bounty_hunter.blink_dash']!
        .blinkMobility!
        .maxObstacleWidth;
    expect(right - left, 138);
    expect(maxWidth, right - left);
    var count = 0;
    for (final chunk in stagedAuthoredTerrain.chunks) {
      for (final p in chunk.polygons.where(
        (p) => p.id.placementKey?.contains('tent') == true,
      )) {
        final xs = p.vertices.map((v) => v.xTicks).toList()..sort();
        expect(
          (xs.last - xs.first) / 1024,
          lessThanOrEqualTo(maxWidth),
          reason: '${chunk.chunkKey}/${p.id.placementKey}',
        );
        count++;
      }
    }
    expect(count, greaterThanOrEqualTo(24));
  });

  for (final hz in [30, 60, 120]) {
    for (final direction in [-1, 1]) {
      test(
        'actual woodcamp tent crossed once with full recovery: $direction at $hz Hz',
        () {
          final core = _core(
            actual,
            x: direction > 0 ? left - 24 : right + 24,
            hz: hz,
          );
          _settle(core, hz);
          final origin = core.playerPosX, distance = core.distance;
          final frames = <int>{};
          var relocations = 0;
          var previousX = origin;
          for (var i = 0; i <= hz; i++) {
            final tick = core.tick + 1;
            core.applyCommands([
              if (i == 0)
                MoveAxisCommand(tick: tick, axis: direction.toDouble()),
              if (i == 0 || i == 2) DashPressedCommand(tick: tick),
            ]);
            core.stepOneTick();
            final e = core.buildSnapshot().playerEntity!;
            if ((e.pos.x - previousX).abs() > 5) {
              relocations++;
              expect(e.anim, AnimKey.teleportOut);
              expect(
                e.animFrame! ~/ (.05 * hz).round(),
                4,
                reason: 'relocate only on transparent frame',
              );
              expect(i, (hz * .2).ceil());
            }
            if (e.anim == AnimKey.teleportOut) {
              frames.add(e.animFrame! ~/ (.05 * hz).round());
            }
            previousX = e.pos.x;
          }
          expect(core.gameOver, false);
          expect(relocations, 1);
          expect(frames, containsAll(List.generate(10, (i) => i)));
          if (direction > 0) {
            expect(core.playerPosX - 10.8, greaterThan(right));
            expect(
              core.distance - distance,
              closeTo(core.playerPosX - origin, .01),
            );
          } else {
            expect(core.playerPosX + 10.8, lessThan(left));
            expect(core.distance, distance);
          }
          expect(
            core.buildSnapshot().playerEntity!.anim,
            isNot(AnimKey.teleportOut),
          );
        },
      );
    }
  }

  for (final mode in ['too wide', 'too far', 'blocked exit']) {
    test('$mode rejects without cost, cooldown or delayed relocation', () {
      final start = mode == 'too far' ? 200.0 : 260.0;
      final edge = mode == 'too wide' ? 422.0 : 421.0;
      final geometry = _terrain([
        _rect('tent', 283, 100, edge, 224),
        if (mode == 'blocked exit') _rect('neighbor', 430, 100, 470, 224),
      ]);
      final core = _core(geometry, x: start);
      _settle(core, 60);
      final before = core.buildSnapshot().hud;
      for (var i = 0; i < 40; i++) {
        final tick = core.tick + 1;
        core.applyCommands([if (i == 0) DashPressedCommand(tick: tick)]);
        core.stepOneTick();
        expect(
          core.buildSnapshot().playerEntity!.anim,
          isNot(AnimKey.teleportOut),
        );
      }
      expect(core.playerPosX, closeTo(start, .01));
      expect(core.buildSnapshot().hud.stamina, before.stamina);
      expect(
        core.buildSnapshot().hud.cooldownTicksLeft,
        before.cooldownTicksLeft,
      );
    });
  }

  test('open-air blink preserves height during phases and resumes falling', () {
    final core = _core(_terrain([]), x: 260);
    _settle(core, 60);
    core.applyCommands([JumpPressedCommand(tick: core.tick + 1)]);
    core.stepOneTick();
    for (var i = 0; i < 5; i++) {
      core.applyCommands([]);
      core.stepOneTick();
    }
    final x = core.playerPosX, y = core.playerPosY;
    for (var i = 0; i < 30; i++) {
      core.applyCommands([if (i == 0) DashPressedCommand(tick: core.tick + 1)]);
      core.stepOneTick();
      expect(core.playerPosY, closeTo(y, .01));
    }
    expect(core.playerPosX - x, closeTo(110, .01));
    for (var i = 0; i < 6; i++) {
      core.applyCommands([]);
      core.stepOneTick();
    }
    expect(core.playerPosY, greaterThan(y));
  });

  test('jump interruption cannot execute an abandoned blink', () {
    final core = _core(_terrain([]), x: 260);
    _settle(core, 60);
    for (var i = 0; i < 45; i++) {
      final tick = core.tick + 1;
      core.applyCommands([
        if (i == 0) DashPressedCommand(tick: tick),
        if (i == 4) JumpPressedCommand(tick: tick),
      ]);
      core.stepOneTick();
    }
    expect(core.playerPosX, closeTo(260, .01));
  });

  for (final gun in [
    ProjectileId.hunterPistol,
    ProjectileId.hunterCrossbow,
    ProjectileId.hunterShotgun,
  ]) {
    test(
      '$gun uses final attack strip and restores transparent teleport frame',
      () {
        final r = bountyHunterRenderAnim(gun);
        expect(r.frameCountsByKey[AnimKey.lunge], 5);
        expect(
          r.compositeFramesByKey[AnimKey.lunge]!.first.single.source.y,
          29 * 54,
        );
        expect(r.compositeFramesByKey[AnimKey.teleportOut]!.length, 10);
        expect(r.compositeFramesByKey[AnimKey.teleportOut]![4], isEmpty);
      },
    );
  }
}

void _settle(GameCore core, int hz) {
  for (var i = 0; i < hz * 2; i++) {
    core.applyCommands([]);
    core.stepOneTick();
  }
}

GameCore _core(TerrainGeometry geometry, {required double x, int hz = 60}) =>
    GameCore.terrainMotionHarness(
      seed: 7,
      tickHz: hz,
      terrainGeometry: geometry,
      playerCharacter: bountyHunterCharacter,
      equippedLoadoutOverride: const EquippedLoadoutDef(
        mask: LoadoutSlotMask.all,
        mainWeaponId: WeaponId.hunterBlade,
        offhandWeaponId: WeaponId.hunterBombKit,
        spellBookId: SpellBookId.hunterFieldKit,
        projectileSlotSpellId: ProjectileId.hunterPistol,
        abilityPrimaryId: 'bounty_hunter.lunge_slash',
        abilitySecondaryId: 'bounty_hunter.blast_bomb',
        abilityProjectileId: 'bounty_hunter.snap_shot',
        abilitySpellId: 'bounty_hunter.hunters_focus',
        abilityMobilityId: 'bounty_hunter.blink_dash',
        abilityJumpId: 'bounty_hunter.jump',
      ),
      levelDefinition: LevelDefinition(
        id: LevelId.forest,
        groundTopY: 224,
        chunkPatternSource: const ChunkPatternListSource(easyPatterns: []),
        tuning: CoreTuning(
          camera: const CameraTuning(speedLagMulX: 0, followThresholdRatio: 1),
          track: TrackTuning(enabled: false, playerStartX: x),
        ),
      ),
    );
TerrainGeometry _terrain(List<TerrainPolygonInput> obstacles) =>
    const TerrainCompiler().compile([
      _rect('ground', 0, 224, 1000, 270),
      ...obstacles,
    ], geometryVersion: 1);
TerrainPolygonInput _rect(String id, double l, double t, double r, double b) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$id',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: id,
      ),
      vertices: [(l, t), (r, t), (r, b), (l, b)],
    );
