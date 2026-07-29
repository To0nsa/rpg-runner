import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/collision/static_world_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/levels/level_definition.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/tuning/core_tuning.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:test/test.dart';

void main() {
  group('Derf kinematic terrain placement', () {
    test('accepts flat and inclusive 15-degree solid obstacle tops', () {
      final flat = _resolve(
        _geometry(<TerrainPolygonInput>[_platform('flat', 0, 300, 100, 400)]),
        x: 50,
        supportY: 300,
      );
      final atLimit = _resolve(
        _geometry(<TerrainPolygonInput>[
          _polygon('slope-15', <(double, double)>[
            (0, 300),
            (112, 270),
            (112, 400),
            (0, 400),
          ]),
        ]),
        x: 56,
        supportY: 285,
      );

      expect(flat.accepted, isTrue);
      expect(flat.absoluteSlopeAngleUnits, 0);
      expect(atLimit.accepted, isTrue);
      expect(
        atLimit.absoluteSlopeAngleUnits,
        lessThanOrEqualTo(15 * terrainSlopeAngleUnitsPerDegree),
      );
      expect(_bodyX(atLimit), 56);
    });

    test('rejects support just over the 15-degree profile limit', () {
      final result = _resolve(
        _geometry(<TerrainPolygonInput>[
          _polygon('slope-over-15', <(double, double)>[
            (0, 300),
            (112, 269),
            (112, 400),
            (0, 400),
          ]),
        ]),
        x: 56,
        supportY: 284.5,
      );

      expect(result.accepted, isFalse);
      expect(result.validity, TerrainPlacementValidity.profileIneligible);
    });

    test('accepts exactly 32 px and rejects a just-narrower perch', () {
      final exact = _resolve(
        _geometry(<TerrainPolygonInput>[
          _platform('exact-32', 0, 300, 32, 400),
        ]),
        x: 16,
        supportY: 300,
      );
      final narrow = _resolve(
        _geometry(<TerrainPolygonInput>[
          _platform('narrow-31-5', 0, 300, 31.5, 400),
        ]),
        x: 15.5,
        supportY: 300,
      );

      expect(exact.accepted, isTrue);
      expect(_bodyX(exact), 16);
      expect(narrow.accepted, isFalse);
      expect(
        narrow.validity,
        TerrainPlacementValidity.insufficientSupportWidth,
      );
    });

    test('clamps both edge markers only within the intended support', () {
      final geometry = _geometry(<TerrainPolygonInput>[
        _platform('wide', 0, 300, 100, 400),
      ]);
      final left = _resolve(geometry, x: 0, supportY: 300);
      final right = _resolve(geometry, x: 100, supportY: 300);

      expect(left.accepted, isTrue);
      expect(left.sameSupportClamped, isTrue);
      expect(_bodyX(left), 16);
      expect(right.accepted, isTrue);
      expect(right.sameSupportClamped, isTrue);
      expect(_bodyX(right), 84);
      expect(left.supportEdgeId, right.supportEdgeId);
    });

    test('rejects blocked headroom and an adjacent solid wall', () {
      final headroom = _resolve(
        _geometry(<TerrainPolygonInput>[
          _platform('floor', 0, 300, 120, 400),
          _platform('ceiling', 0, 220, 120, 255),
        ]),
        x: 60,
        supportY: 300,
      );
      final wall = _resolve(
        _geometry(<TerrainPolygonInput>[
          _platform('floor', 0, 300, 120, 400),
          _platform('wall', 50, 220, 60, 290),
        ]),
        x: 45,
        supportY: 300,
      );

      expect(headroom.accepted, isFalse);
      expect(headroom.validity, TerrainPlacementValidity.blockedClearance);
      expect(headroom.blockingEdgeId, isNotNull);
      expect(wall.accepted, isFalse);
      expect(wall.validity, TerrainPlacementValidity.blockedClearance);
      expect(wall.blockingEdgeId, isNotNull);
    });

    test('never searches an unrelated support or ordinary ground fallback', () {
      final geometry = _geometry(<TerrainPolygonInput>[
        _platform('narrow-intended', 0, 300, 20, 400),
        _platform('unrelated-ground', -100, 500, 200, 650),
      ]);
      final narrow = _resolve(geometry, x: 10, supportY: 300);
      final absent = _resolve(geometry, x: 80, supportY: 400);
      final legacyFallbackRejected = _resolve(
        geometry,
        x: 80,
        supportY: 500,
        intendedSupportAvailable: false,
      );

      expect(
        narrow.validity,
        TerrainPlacementValidity.insufficientSupportWidth,
      );
      expect(narrow.supportEdgeId?.shapeId, 'narrow-intended');
      expect(absent.validity, TerrainPlacementValidity.intendedSupportMissing);
      expect(absent.supportEdgeId, isNull);
      expect(
        legacyFallbackRejected.validity,
        TerrainPlacementValidity.intendedSupportMissing,
      );
    });

    test('emits a stable canonical placement diagnostic', () {
      final geometry = _geometry(<TerrainPolygonInput>[
        _platform('perch', 0, 300, 100, 400),
      ]);
      final first = _resolve(geometry, x: 0, supportY: 300);
      final second = _resolve(geometry, x: 0, supportY: 300);

      expect(first.diagnostic, second.diagnostic);
      expect(first.diagnostic, startsWith('terrain-spawn-placement-v1|'));
      expect(first.diagnostic, contains('|profile=enemy:derf|'));
      expect(first.diagnostic, contains('|validity=valid|'));
      expect(first.diagnostic, contains('|support=0/4:test/-/5:perch/'));
      expect(first.diagnostic, endsWith('|clamped=1'));
    });
  });

  test(
    'gentle-slope placement preserves Derf cast and presentation semantics',
    () {
      final slopePlacement = _resolve(
        _geometry(<TerrainPolygonInput>[
          _polygon('gentle-slope', <(double, double)>[
            (0, 300),
            (112, 270),
            (112, 400),
            (0, 400),
          ]),
        ]),
        x: 56,
        supportY: 285,
      );
      final flatPlacement = _resolve(
        _geometry(<TerrainPolygonInput>[_platform('flat', 0, 300, 112, 400)]),
        x: 56,
        supportY: 300,
      );

      final slope = _castFrom(slopePlacement);
      final flat = _castFrom(flatPlacement);

      expect(slope.facing, Facing.left);
      expect(slope.artFacing, Facing.left);
      expect(slope.abilityId, 'derf.fire_explosion');
      expect(slope.targetX, flat.targetX);
      expect(slope.targetY, flat.targetY);
      expect(slope.executeTick, flat.executeTick);
      expect(slope.activeFacing, flat.activeFacing);
      final archetype = const EnemyCatalog().get(EnemyId.derf);
      expect(archetype.deathBehavior, DeathBehavior.instant);
      expect(
        archetype.castTargetPolicy,
        EnemyCastTargetPolicy.predictedPlayerCenter,
      );
      expect(archetype.facingPolicy, EnemyFacingPolicy.facePlayerAlways);
    },
  );

  group('Derf streamed terrain placement', () {
    test('spawns a resolved obstacle marker at the same-support clamp', () {
      const pattern = ChunkPattern(
        name: 'derf-valid-obstacle',
        solids: <SolidRel>[
          SolidRel(
            x: 400,
            aboveGroundTop: 96,
            width: 96,
            height: 48,
            sides: SolidRel.sideAll,
          ),
        ],
        spawnMarkers: <SpawnMarker>[
          SpawnMarker(
            enemyId: EnemyId.derf,
            x: 400,
            chancePercent: 100,
            salt: 1,
            placement: SpawnPlacementMode.obstacleTop,
          ),
        ],
      );
      final core = GameCore.terrainMotionHarness(
        seed: 7,
        levelDefinition: _streamedLevel(pattern),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _geometry(<TerrainPolygonInput>[
          _platform('ground', 0, 300, 2000, 600),
          _platform('obstacle', 400, 204, 496, 252),
        ]),
      );

      core.stepOneTick();
      final derfs = core
          .buildSnapshot()
          .entities
          .where((entity) => entity.enemyId == EnemyId.derf)
          .toList();

      expect(derfs, hasLength(1));
      expect(derfs.single.pos.x, 416);
      expect(derfs.single.rotationRad, 0);
      expect(core.lastSpawnPlacementDiagnostic, contains('|validity=valid|'));
      expect(core.lastSpawnPlacementDiagnostic, endsWith('|clamped=1'));
    });

    test('skips a legacy obstacle fallback with a stable diagnostic', () {
      const pattern = ChunkPattern(
        name: 'derf-invalid-fallback',
        solids: <SolidRel>[
          SolidRel(
            x: 400,
            aboveGroundTop: 96,
            width: 96,
            height: 16,
            sides: SolidRel.sideTop,
            oneWayTop: true,
          ),
        ],
        spawnMarkers: <SpawnMarker>[
          SpawnMarker(
            enemyId: EnemyId.derf,
            x: 450,
            chancePercent: 100,
            salt: 2,
            placement: SpawnPlacementMode.obstacleTop,
          ),
        ],
      );
      final core = GameCore.terrainMotionHarness(
        seed: 8,
        levelDefinition: _streamedLevel(pattern),
        playerCharacter: eloiseCharacter,
        terrainGeometry: _geometry(<TerrainPolygonInput>[
          _platform('ground', 0, 300, 2000, 600),
        ]),
      );

      core.stepOneTick();

      expect(
        core.buildSnapshot().entities.any(
          (entity) => entity.enemyId == EnemyId.derf,
        ),
        isFalse,
      );
      expect(
        core.lastSpawnPlacementDiagnostic,
        contains('|validity=intendedSupportMissing|'),
      );
    });
  });
}

TerrainSpawnPlacementResult _resolve(
  TerrainGeometry geometry, {
  required double x,
  required double supportY,
  bool intendedSupportAvailable = true,
}) {
  const catalog = EnemyCatalog();
  final collider = catalog.get(EnemyId.derf).collider;
  return _authority(geometry).resolveSpawnPlacement(
    TerrainSpawnPlacementRequest(
      profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: catalog,
        enemyId: EnemyId.derf,
        facing: Facing.left,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(
        x,
        supportY - (collider.offsetY + collider.halfY),
      ),
      supportSelection: TerrainSpawnSupportSelection.obstacleTop,
      requestedSupportYTicks: physicsCoordinateToTicks(supportY),
      intendedSourceAvailable: intendedSupportAvailable,
      allowSameSupportClamp: true,
    ),
  );
}

double _bodyX(TerrainSpawnPlacementResult placement) =>
    placement.bodyCenter!.xTicks / terrainPhysicsTicksPerWorldUnit;

TerrainMultiBodyWorldMotionAuthority _authority(TerrainGeometry geometry) {
  final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: 60,
  );
  final player = PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: movement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;
  return TerrainMultiBodyWorldMotionAuthority(
    geometry: geometry,
    playerProfile: player.terrainTraversalProfile,
  );
}

({
  Facing facing,
  Facing artFacing,
  String abilityId,
  double targetX,
  double targetY,
  int executeTick,
  Facing activeFacing,
})
_castFrom(TerrainSpawnPlacementResult placement) {
  expect(placement.accepted, isTrue);
  final world = EcsWorld(seed: 99);
  final factory = EntityFactory(world);
  const catalog = EnemyCatalog();
  final derfArchetype = catalog.get(EnemyId.derf);
  final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: 60,
  );
  final playerArchetype = PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: movement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;
  final player = factory.createPlayer(
    posX: 0,
    posY: 200,
    velX: 30,
    velY: -12,
    facing: Facing.right,
    grounded: true,
    body: playerArchetype.body,
    collider: playerArchetype.collider,
    health: playerArchetype.health,
    mana: playerArchetype.mana,
    stamina: playerArchetype.stamina,
  );
  final derf = factory.createEnemy(
    enemyId: EnemyId.derf,
    posX: placement.bodyCenter!.xTicks / terrainPhysicsTicksPerWorldUnit,
    posY: placement.bodyCenter!.yTicks / terrainPhysicsTicksPerWorldUnit,
    velX: 0,
    velY: 0,
    facing: Facing.right,
    artFacing: derfArchetype.artFacingDir,
    body: derfArchetype.body,
    collider: derfArchetype.collider,
    health: derfArchetype.health,
    mana: derfArchetype.mana,
    stamina: derfArchetype.stamina,
    tags: derfArchetype.tags,
    resistance: derfArchetype.resistance,
  );
  world.cooldown.setTicksLeft(derf, 2, 0);
  EnemyCastSystem(
    unocoDemonTuning: UnocoDemonTuningDerived.from(
      const UnocoDemonTuning(),
      tickHz: 60,
    ),
    enemyCatalog: catalog,
    projectiles: const ProjectileCatalog(),
    abilities: AbilityCatalog.shared,
  ).step(world, player: player, currentTick: 10);

  final enemyIndex = world.enemy.indexOf(derf);
  final intentIndex = world.targetPointIntent.indexOf(derf);
  final activeIndex = world.activeAbility.indexOf(derf);
  return (
    facing: world.enemy.facing[enemyIndex],
    artFacing: world.enemy.artFacing[enemyIndex],
    abilityId: world.targetPointIntent.abilityId[intentIndex],
    targetX: world.targetPointIntent.targetX[intentIndex],
    targetY: world.targetPointIntent.targetY[intentIndex],
    executeTick: world.targetPointIntent.tick[intentIndex],
    activeFacing: world.activeAbility.facing[activeIndex],
  );
}

TerrainGeometry _geometry(List<TerrainPolygonInput> polygons) =>
    const TerrainCompiler().compile(polygons, geometryVersion: 1);

TerrainPolygonInput _platform(
  String shapeId,
  double minX,
  double topY,
  double maxX,
  double bottomY,
) => _polygon(shapeId, <(double, double)>[
  (minX, topY),
  (maxX, topY),
  (maxX, bottomY),
  (minX, bottomY),
]);

TerrainPolygonInput _polygon(String shapeId, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$shapeId',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: shapeId,
      ),
      vertices: vertices,
    );

LevelDefinition _streamedLevel(ChunkPattern pattern) => LevelDefinition(
  id: LevelId.field,
  chunkPatternSource: ChunkPatternListSource(
    easyPatterns: <ChunkPattern>[pattern],
    hardPatterns: <ChunkPattern>[pattern],
  ),
  staticWorldGeometry: const StaticWorldGeometry(
    groundPlane: StaticGroundPlane(topY: 300),
  ),
  tuning: const CoreTuning(
    track: TrackTuning(
      enabled: true,
      chunkWidth: 2048,
      spawnAheadMargin: 0,
      playerStartX: 100,
    ),
  ),
  earlyPatternChunks: 0,
  noEnemyChunks: 0,
);
