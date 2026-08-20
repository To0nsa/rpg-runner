import 'package:runner_core/commands/command.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_item_def.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:test/test.dart';

void main() {
  test('normal stream republishes one deterministic terrain world', () {
    GameCore build() => GameCore(
      seed: 9127,
      levelDefinition: LevelRegistry.byId(
        LevelId.field,
      ).copyWith(noEnemyChunks: 9999),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );

    final first = build();
    final second = build();
    final initialVersion = _expectSameTerrainWorld(first, second);
    expect(initialVersion, 1);
    expect(first.playerGrounded, isTrue);
    expect(
      () => first.queueTerrainHarnessGeometryReplacement(
        TerrainGeometry(version: 2, polygons: const [], edges: const []),
      ),
      throwsStateError,
    );

    for (var nextTick = 1; nextTick <= 900; nextTick++) {
      final commands = <Command>[MoveAxisCommand(tick: nextTick, axis: 1)];
      first.applyCommands(commands);
      second.applyCommands(commands);
      first.stepOneTick();
      second.stepOneTick();
      expect(first.gameOver, isFalse, reason: 'first tick $nextTick');
      expect(second.gameOver, isFalse, reason: 'second tick $nextTick');
      if (nextTick % 30 == 0) {
        _expectSameTerrainWorld(first, second);
        expect(first.playerGrounded, isTrue, reason: 'tick $nextTick');
      }
    }

    expect(_expectSameTerrainWorld(first, second), greaterThan(initialVersion));
  });

  test('terrain publication precedes markers and both pickup policies', () {
    var enemyCount = 0;
    var collectibleCount = 0;
    var restorationCount = 0;
    const markerPattern = ChunkPattern(
      name: 'forest_flat_marker_fixture',
      chunkKey: 'forest_earlt_flat',
      spawnMarkers: <SpawnMarker>[
        SpawnMarker(
          enemyId: EnemyId.grojib,
          x: 160,
          chancePercent: 100,
          salt: 1,
        ),
        SpawnMarker(
          enemyId: EnemyId.hashash,
          x: 320,
          chancePercent: 100,
          salt: 2,
        ),
      ],
    );
    const markerSource = ChunkPatternListSource(
      earlyPatterns: <ChunkPattern>[markerPattern],
      easyPatterns: <ChunkPattern>[markerPattern],
      normalPatterns: <ChunkPattern>[markerPattern],
      hardPatterns: <ChunkPattern>[markerPattern],
    );
    final level = LevelRegistry.byId(LevelId.forest).copyWith(
      chunkPatternSource: markerSource,
      earlyPatternChunks: 0,
      easyPatternChunks: 100,
      normalPatternChunks: 0,
      noEnemyChunks: 0,
    );

    for (var seed = 0; seed < 8; seed++) {
      final core = GameCore(
        seed: seed,
        levelDefinition: level,
        playerCharacter: PlayerCharacterRegistry.eloise,
      );
      core.applyCommands(const <Command>[]);
      core.stepOneTick();
      expect(core.gameOver, isFalse, reason: 'seed $seed');
      expect(core.playerGrounded, isTrue, reason: 'seed $seed');
      final entities = core.buildSnapshot().entities;
      final enemies = entities.where(
        (entity) =>
            entity.enemyId == EnemyId.grojib ||
            entity.enemyId == EnemyId.hashash,
      );
      expect(enemies, everyElement(_isGroundedEntity));
      enemyCount += enemies.length;
      collectibleCount += entities
          .where(
            (entity) =>
                entity.kind == EntityKind.pickup &&
                entity.pickupVariant == PickupVariant.collectible,
          )
          .length;
      restorationCount += entities
          .where(
            (entity) =>
                entity.kind == EntityKind.pickup &&
                entity.pickupVariant != PickupVariant.collectible,
          )
          .length;
    }

    expect(enemyCount, greaterThan(0));
    expect(collectibleCount, greaterThan(0));
    expect(restorationCount, greaterThan(0));
  });

  test('normal construction admits current streamed enemy policies', () {
    const pattern = ChunkPattern(
      name: 'all_enemy_policies',
      chunkKey: 'forest_earlt_flat',
      spawnMarkers: <SpawnMarker>[
        SpawnMarker(
          enemyId: EnemyId.grojib,
          x: 120,
          chancePercent: 100,
          salt: 1,
        ),
        SpawnMarker(
          enemyId: EnemyId.hashash,
          x: 240,
          chancePercent: 100,
          salt: 2,
        ),
        SpawnMarker(
          enemyId: EnemyId.unocoDemon,
          x: 360,
          chancePercent: 100,
          salt: 3,
        ),
      ],
    );
    const patternSource = ChunkPatternListSource(
      earlyPatterns: <ChunkPattern>[pattern],
      easyPatterns: <ChunkPattern>[pattern],
      normalPatterns: <ChunkPattern>[pattern],
      hardPatterns: <ChunkPattern>[pattern],
    );
    final registered = LevelRegistry.byId(LevelId.forest);
    final level = LevelDefinition(
      id: registered.id,
      chunkPatternSource: patternSource,
      groundTopY: registered.groundTopY,
      tuning: registered.tuning,
      cameraCenterY: registered.cameraCenterY,
      killPlaneY: registered.killPlaneY,
      earlyPatternChunks: 0,
      easyPatternChunks: 0,
      normalPatternChunks: 0,
      noEnemyChunks: 0,
      visualThemeId: registered.visualThemeId,
    );

    final core = GameCore(
      seed: 71,
      levelDefinition: level,
      playerCharacter: PlayerCharacterRegistry.eloise,
    );
    core.applyCommands(const <Command>[]);
    core.stepOneTick();

    final enemies = core
        .buildSnapshot()
        .entities
        .where((entity) => entity.kind == EntityKind.enemy)
        .toList(growable: false);
    for (final enemyId in <EnemyId>[
      EnemyId.grojib,
      EnemyId.hashash,
      EnemyId.unocoDemon,
    ]) {
      expect(
        enemies.where((entity) => entity.enemyId == enemyId),
        isNotEmpty,
        reason: '$enemyId must survive normal terrain placement',
      );
    }
    expect(
      enemies.where(
        (entity) =>
            entity.enemyId == EnemyId.grojib ||
            entity.enemyId == EnemyId.hashash,
      ),
      everyElement(_isGroundedEntity),
    );
    expect(
      enemies.where((entity) => entity.enemyId == EnemyId.unocoDemon),
      everyElement((entity) => !entity.grounded),
    );
    expect(core.gameOver, isFalse);
  });

  test('normal stream retains the terrain fall-death policy', () {
    final core = GameCore(
      seed: 19,
      levelDefinition: LevelRegistry.byId(LevelId.field),
      playerCharacter: PlayerCharacterRegistry.eloise,
    );
    core.setPlayerPosXYUnsafeForTest(core.playerPosX, 2000);

    core.applyCommands(const <Command>[]);
    core.stepOneTick();

    expect(core.gameOver, isTrue);
    expect(core.playerGrounded, isFalse);
  });

  test('normal construction integrates ballistic projectiles', () {
    final core = GameCore(
      seed: 29,
      levelDefinition: LevelRegistry.byId(
        LevelId.field,
      ).copyWith(noEnemyChunks: 9999),
      playerCharacter: PlayerCharacterRegistry.eloise,
      projectileCatalog: const _BallisticProjectileCatalog(),
    );

    core.applyCommands(const <Command>[
      AimDirCommand(tick: 1, x: 1, y: 0),
      ProjectilePressedCommand(tick: 1),
    ]);
    core.stepOneTick();

    EntityRenderSnapshot? launched;
    for (var i = 0; i < 60 && launched == null; i += 1) {
      for (final entity in core.buildSnapshot().entities) {
        if (entity.kind == EntityKind.projectile) {
          launched = entity;
          break;
        }
      }
      if (launched == null) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }
    }
    expect(launched, isNotNull);
    final launchedProjectile = launched!;

    core.applyCommands(const <Command>[]);
    core.stepOneTick();
    final integrated = core.buildSnapshot().entities.singleWhere(
      (entity) => entity.id == launchedProjectile.id,
    );
    expect(integrated.pos.x, greaterThan(launchedProjectile.pos.x));
    expect(integrated.pos.y, greaterThan(launchedProjectile.pos.y));
    expect(core.gameOver, isFalse);
  });

  for (final levelId in <LevelId>[LevelId.field, LevelId.forest]) {
    test('$levelId long command run stays deterministic', () {
      GameCore build() => GameCore(
        seed: 4401,
        levelDefinition: LevelRegistry.byId(
          levelId,
        ).copyWith(noEnemyChunks: 9999),
        playerCharacter: PlayerCharacterRegistry.eloise,
      );
      final first = build();
      final second = build();

      for (var nextTick = 1; nextTick <= 1800; nextTick++) {
        final xWithinChunk = first.playerPosX % 600;
        final approachingWoodPile =
            levelId == LevelId.forest &&
            first.playerGrounded &&
            xWithinChunk >= 320 &&
            xWithinChunk <= 380;
        final commands = <Command>[
          MoveAxisCommand(tick: nextTick, axis: 1),
          if (approachingWoodPile ||
              (levelId == LevelId.field && nextTick % 60 == 0))
            JumpPressedCommand(tick: nextTick),
        ];
        first.applyCommands(commands);
        second.applyCommands(commands);
        first.stepOneTick();
        second.stepOneTick();
        expect(first.gameOver, isFalse, reason: 'first tick $nextTick');
        expect(second.gameOver, isFalse, reason: 'second tick $nextTick');
        if (nextTick % 60 == 0) {
          expect(second.playerPosX, first.playerPosX);
          expect(second.playerPosY, first.playerPosY);
          expect(second.playerGrounded, first.playerGrounded);
          _expectSameTerrainWorld(first, second);
        }
      }

      expect(first.distance, greaterThan(5000));
      expect(second.distance, first.distance);
    });
  }
}

bool _isGroundedEntity(EntityRenderSnapshot entity) => entity.grounded;

int _expectSameTerrainWorld(GameCore first, GameCore second) {
  final firstRender = first.buildSnapshot().stagedTerrainRenderSnapshot;
  final secondRender = second.buildSnapshot().stagedTerrainRenderSnapshot;
  final firstDebug = first.buildTerrainPlayerDebugSnapshot();
  final secondDebug = second.buildTerrainPlayerDebugSnapshot();
  expect(firstRender, isNotNull);
  expect(secondRender, isNotNull);
  expect(firstDebug, isNotNull);
  expect(secondDebug, isNotNull);
  expect(secondRender!.geometryVersion, firstRender!.geometryVersion);
  expect(firstDebug!.geometryVersion, firstRender.geometryVersion);
  expect(secondDebug!.geometryVersion, secondRender.geometryVersion);
  expect(
    secondRender.polygons.map((polygon) => polygon.sourceId),
    orderedEquals(firstRender.polygons.map((polygon) => polygon.sourceId)),
  );
  expect(
    secondRender.edges.map((edge) => edge.id),
    orderedEquals(firstRender.edges.map((edge) => edge.id)),
  );
  expect(secondDebug.supportEdgeId, firstDebug.supportEdgeId);
  return firstRender.geometryVersion;
}

class _BallisticProjectileCatalog extends ProjectileCatalog {
  const _BallisticProjectileCatalog();

  @override
  ProjectileItemDef get(ProjectileId id) {
    final base = super.get(id);
    if (id != ProjectileId.acidBolt) return base;
    return ProjectileItemDef(
      id: base.id,
      weaponType: base.weaponType,
      speedUnitsPerSecond: base.speedUnitsPerSecond,
      lifetimeSeconds: base.lifetimeSeconds,
      colliderSizeX: base.colliderSizeX,
      colliderSizeY: base.colliderSizeY,
      ballistic: true,
      gravityScale: base.gravityScale,
      damageType: base.damageType,
      procs: base.procs,
      stats: base.stats,
    );
  }
}
