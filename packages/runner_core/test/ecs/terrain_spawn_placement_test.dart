import 'dart:convert';
import 'dart:io';

import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/restoration_item_store.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/terrain_surface_extractor.dart';
import 'package:runner_core/navigation/terrain_surface_spatial_index.dart';
import 'package:runner_core/navigation/types/terrain_navigation_surface.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_archetype.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spawn_service.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/chunk_pattern_source.dart';
import 'package:runner_core/track/track_streamer.dart';
import 'package:runner_core/tuning/collectible_tuning.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/restoration_item_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';
import 'package:runner_core/util/deterministic_rng.dart';
import 'package:test/test.dart';

import '../fixtures/terrain_spawn_placement_fixture.dart';

void main() {
  group('shared terrain spawn placement', () {
    test('retains ground, highest-surface, and obstacle-top intent', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _polygon('ground_slope', const <(double, double)>[
          (0, 300),
          (300, 240),
          (300, 500),
          (0, 500),
        ]),
        _rectangle('lower', 400, 300, 800, 500),
        _rectangle('highest', 450, 220, 750, 260),
        _rectangle('obstacle_ground', 800, 300, 1100, 500),
        _rectangle('obstacle', 900, 240, 1000, 280),
      ]);
      final slope = _surface(fixture, 'ground_slope');

      final ground = _enemyPlacement(
        fixture,
        enemyId: EnemyId.grojib,
        x: 100,
        selection: TerrainSpawnSupportSelection.ground,
        requestedSupportY: 280,
      );
      final highest = _enemyPlacement(
        fixture,
        enemyId: EnemyId.hashash,
        x: 600,
        selection: TerrainSpawnSupportSelection.highestSurfaceAtX,
      );
      final obstacle = _enemyPlacement(
        fixture,
        enemyId: EnemyId.derf,
        x: 950,
        selection: TerrainSpawnSupportSelection.obstacleTop,
        requestedSupportY: 240,
      );
      final exactSlope = _enemyPlacement(
        fixture,
        enemyId: EnemyId.hashash,
        x: 150,
        selection: TerrainSpawnSupportSelection.ground,
        requestedSupportY: 999,
        intendedSupport: slope,
      );

      expect(ground.accepted, isTrue);
      expect(ground.supportEdgeId!.shapeId, 'ground_slope');
      expect(highest.accepted, isTrue);
      expect(highest.supportEdgeId!.shapeId, 'highest');
      expect(obstacle.accepted, isTrue);
      expect(obstacle.supportEdgeId!.shapeId, 'obstacle');
      expect(exactSlope.accepted, isTrue);
      expect(exactSlope.supportEdgeId, slope.id);
    });

    test(
      'selects semantic ground and obstacle support without rectangle Y',
      () {
        final fixture = _fixture(<TerrainPolygonInput>[
          _rectangle('ground', 0, 300, 500, 500, surfaceKind: 'ground'),
          _rectangle('obstacle', 180, 240, 320, 280, surfaceKind: 'obstacle'),
        ]);

        final ground = _enemyPlacement(
          fixture,
          enemyId: EnemyId.grojib,
          x: 100,
          selection: TerrainSpawnSupportSelection.ground,
        );
        final obstacle = _enemyPlacement(
          fixture,
          enemyId: EnemyId.derf,
          x: 250,
          selection: TerrainSpawnSupportSelection.obstacleTop,
        );

        expect(ground.accepted, isTrue);
        expect(ground.supportEdgeId!.shapeId, 'ground');
        expect(obstacle.accepted, isTrue);
        expect(obstacle.supportEdgeId!.shapeId, 'obstacle');
      },
    );

    test('applies enemy profile limits and optional same-support clamp', () {
      final slopeFixture = _fixture(<TerrainPolygonInput>[
        _polygon('fifty_degrees', const <(double, double)>[
          (0, 300),
          (100, 180),
          (100, 500),
          (0, 500),
        ]),
      ]);
      final slope = _surface(slopeFixture, 'fifty_degrees');

      final grojib = _enemyPlacement(
        slopeFixture,
        enemyId: EnemyId.grojib,
        x: 50,
        selection: TerrainSpawnSupportSelection.ground,
        intendedSupport: slope,
      );
      final hashash = _enemyPlacement(
        slopeFixture,
        enemyId: EnemyId.hashash,
        x: 50,
        selection: TerrainSpawnSupportSelection.ground,
        intendedSupport: slope,
      );

      expect(grojib.validity, TerrainPlacementValidity.profileIneligible);
      expect(hashash.accepted, isTrue);

      final flatFixture = _fixture(<TerrainPolygonInput>[
        _rectangle('finite', 0, 300, 100, 500),
      ]);
      final finite = _surface(flatFixture, 'finite');
      final rejected = _enemyPlacement(
        flatFixture,
        enemyId: EnemyId.grojib,
        x: 0,
        selection: TerrainSpawnSupportSelection.ground,
        intendedSupport: finite,
      );
      final clamped = _enemyPlacement(
        flatFixture,
        enemyId: EnemyId.grojib,
        x: 0,
        selection: TerrainSpawnSupportSelection.ground,
        intendedSupport: finite,
        allowSameSupportClamp: true,
      );

      expect(rejected.validity, TerrainPlacementValidity.outsideSupport);
      expect(clamped.accepted, isTrue);
      expect(clamped.sameSupportClamped, isTrue);
      expect(clamped.supportEdgeId, finite.id);
      expect(clamped.bodyCenter!.xTicks, greaterThan(_ticks(0)));
    });

    test('validates Unoco at its exact point and ignores one-way blockers', () {
      final fixture = _fixture(<TerrainPolygonInput>[
        _rectangle('floor', 0, 300, 500, 500),
        _rectangle('wall', 198, 100, 202, 200),
        _rectangle(
          'one_way',
          250,
          150,
          350,
          156,
          collisionMode: TerrainCollisionMode.oneWay,
        ),
      ]);

      final clear = _flyingPlacement(fixture, x: 100, y: 150);
      final blocked = _flyingPlacement(fixture, x: 200, y: 150);
      final oneWay = _flyingPlacement(fixture, x: 300, y: 150);
      final missingSource = _flyingPlacement(
        fixture,
        x: 100,
        y: 150,
        selection: TerrainSpawnSupportSelection.ground,
        requestedSupportY: 300,
        intendedSourceAvailable: false,
      );

      expect(clear.accepted, isTrue);
      expect(blocked.validity, TerrainPlacementValidity.blockedClearance);
      expect(blocked.blockingEdgeId!.shapeId, 'wall');
      expect(oneWay.accepted, isTrue);
      expect(
        missingSource.validity,
        TerrainPlacementValidity.intendedSupportMissing,
      );
    });
  });

  group('terrain item placement', () {
    test(
      'accepts solid and one-way player-walkable support through 60 degrees',
      () {
        for (final input in <({String id, List<(double, double)> vertices})>[
          (
            id: 'flat',
            vertices: const <(double, double)>[
              (0, 300),
              (100, 300),
              (100, 500),
              (0, 500),
            ],
          ),
          (
            id: 'uphill_60',
            vertices: const <(double, double)>[
              (0, 300),
              (56, 203),
              (56, 500),
              (0, 500),
            ],
          ),
          (
            id: 'downhill_60',
            vertices: const <(double, double)>[
              (0, 203),
              (56, 300),
              (56, 500),
              (0, 500),
            ],
          ),
        ]) {
          final fixture = _fixture(<TerrainPolygonInput>[
            _polygon(input.id, input.vertices),
          ]);
          final result = _itemPlacement(
            fixture,
            x: input.id == 'flat' ? 50 : 28,
            intendedSupport: _surface(fixture, input.id),
            profile: _itemProfile(supportClearance: 30),
          );

          expect(result.accepted, isTrue, reason: input.id);
        }

        final oneWayFixture = _fixture(<TerrainPolygonInput>[
          _rectangle(
            'one_way',
            0,
            300,
            100,
            306,
            collisionMode: TerrainCollisionMode.oneWay,
          ),
        ]);
        final oneWay = _itemPlacement(
          oneWayFixture,
          x: 50,
          intendedSupport: _surface(oneWayFixture, 'one_way'),
        );
        expect(oneWay.accepted, isTrue);

        final tooSteepFixture = _fixture(<TerrainPolygonInput>[
          _polygon('over_60', const <(double, double)>[
            (0, 300),
            (55, 203),
            (55, 500),
            (0, 500),
          ]),
        ]);
        final tooSteep = _itemPlacement(
          tooSteepFixture,
          x: 27.5,
          intendedSupport: _surface(tooSteepFixture, 'over_60'),
          profile: _itemProfile(supportClearance: 30),
        );
        expect(tooSteep.validity, TerrainPlacementValidity.profileIneligible);
      },
    );

    test('requires 20 px support and preserves exact vertical tuning', () {
      final exactFixture = _fixture(<TerrainPolygonInput>[
        _rectangle('exact_20', 0, 100, 20, 140),
      ]);
      final exact = _itemPlacement(
        exactFixture,
        x: 10,
        intendedSupport: _surface(exactFixture, 'exact_20'),
      );

      expect(exact.accepted, isTrue);
      expect(exact.supportPoint, TerrainPoint.fromWorld(10, 100));
      expect(exact.bodyCenter, TerrainPoint.fromWorld(10, 82));

      final narrowFixture = _fixture(<TerrainPolygonInput>[
        _rectangle('under_20', 0, 100, 19.5, 140),
      ]);
      final narrow = _itemPlacement(
        narrowFixture,
        x: 9.5,
        intendedSupport: _surface(narrowFixture, 'under_20'),
      );
      expect(
        narrow.validity,
        TerrainPlacementValidity.insufficientSupportWidth,
      );
    });

    test(
      'requires full AABB clearance and never falls through highest support',
      () {
        for (final blocker in <TerrainPolygonInput>[
          _rectangle('wall', 58, 70, 62, 98),
          _rectangle('ceiling', 40, 65, 60, 75),
        ]) {
          final fixture = _fixture(<TerrainPolygonInput>[
            _rectangle('floor', 0, 100, 100, 140),
            blocker,
          ]);
          final blocked = _itemPlacement(
            fixture,
            x: 50,
            intendedSupport: _surface(fixture, 'floor'),
          );

          expect(
            blocked.validity,
            TerrainPlacementValidity.blockedClearance,
            reason: blocker.identity.shapeId,
          );
          expect(blocked.blockingEdgeId!.shapeId, blocker.identity.shapeId);
        }

        final overlapping = _fixture(<TerrainPolygonInput>[
          _rectangle('lower', 0, 300, 100, 400),
          _rectangle('narrow_highest', 40.5, 200, 59.5, 240),
        ]);
        final result = _itemPlacement(overlapping, x: 50);
        expect(
          result.validity,
          TerrainPlacementValidity.insufficientSupportWidth,
        );
        expect(result.supportEdgeId!.shapeId, 'narrow_highest');
      },
    );
  });

  group('placement determinism', () {
    test('an invalid marker does not shift a later marker roll or result', () {
      const seed = 313;
      const laterChance = 37;
      final laterSalt = Iterable<int>.generate(1000).firstWhere(
        (salt) => mix32(seed ^ 0x85ebca6b ^ salt) % 100 < laterChance,
      );
      final pattern = ChunkPattern(
        name: 'placement-order',
        spawnMarkers: <SpawnMarker>[
          const SpawnMarker(
            enemyId: EnemyId.unocoDemon,
            x: 200,
            chancePercent: 100,
            salt: 1,
          ),
          SpawnMarker(
            enemyId: EnemyId.unocoDemon,
            x: 600,
            chancePercent: laterChance,
            salt: laterSalt,
          ),
        ],
      );

      List<TerrainSpawnPlacementResult> run(_PlacementFixture fixture) {
        final streamer = TrackStreamer(
          seed: seed,
          tuning: const TrackTuning(chunkWidth: 2048, spawnAheadMargin: 0),
          groundTopY: 300,
          patternSource: ChunkPatternListSource(
            easyPatterns: <ChunkPattern>[pattern],
            hardPatterns: <ChunkPattern>[pattern],
          ),
          earlyPatternChunks: 0,
          noEnemyChunks: 0,
        );
        final accepted = <TerrainSpawnPlacementResult>[];
        streamer.step(
          cameraLeft: 0,
          cameraRight: 800,
          spawnEnemy: (request) {
            final placement = _flyingPlacement(
              fixture,
              x: request.x,
              y: request.fallbackSupportY - 150,
              selection: TerrainSpawnSupportSelection.ground,
              requestedSupportY: request.fallbackSupportY,
            );
            if (placement.accepted) accepted.add(placement);
          },
        );
        return accepted;
      }

      final clear = run(
        _fixture(<TerrainPolygonInput>[_rectangle('floor', 0, 300, 2048, 500)]),
      );
      final firstBlocked = run(
        _fixture(<TerrainPolygonInput>[
          _rectangle('floor', 0, 300, 2048, 500),
          _rectangle('first_blocker', 198, 100, 202, 200),
        ]),
      );

      expect(clear, hasLength(2));
      expect(firstBlocked, hasLength(1));
      expect(firstBlocked.single.requestedBodyCenter.xTicks, _ticks(600));
      expect(firstBlocked.single.diagnostic, clear.last.diagnostic);
    });

    test(
      'invalid item attempts are consumed and exhaustion spawns nothing',
      () {
        const seed = 0x20A5;
        final candidates = _collectibleCandidateXs(seed, attemptCount: 2);
        expect((candidates[0] - candidates[1]).abs(), greaterThan(20));
        final geometry = _compile(<TerrainPolygonInput>[
          _rectangle('floor', 0, 300, 2048, 500),
          _rectangle(
            'invalid_first',
            candidates[0] - 9.5,
            200,
            candidates[0] + 9.5,
            240,
          ),
        ]);
        final harness = _spawnHarness(
          seed: seed,
          geometry: geometry,
          collectibleTuning: const CollectibleTuning(
            minPerChunk: 1,
            maxPerChunk: 1,
            spawnStartChunkIndex: 0,
            minSpacingX: 0,
            chunkEdgeMarginX: 32,
            maxAttemptsPerChunk: 2,
          ),
        );

        harness.service.spawnCollectiblesForChunk(
          chunkIndex: 0,
          chunkStartX: 0,
          solids: const <StaticSolid>[],
        );

        expect(harness.world.collectible.denseEntities, hasLength(1));
        final collectible = harness.world.collectible.denseEntities.single;
        final transform = harness.world.transform.indexOf(collectible);
        expect(harness.world.transform.posX[transform], candidates[1]);
        expect(harness.world.transform.posY[transform], 282);

        final exhausted = _spawnHarness(
          seed: seed,
          geometry: _compile(const <TerrainPolygonInput>[]),
          collectibleTuning: const CollectibleTuning(
            minPerChunk: 1,
            maxPerChunk: 1,
            spawnStartChunkIndex: 0,
            minSpacingX: 0,
            chunkEdgeMarginX: 32,
            maxAttemptsPerChunk: 2,
          ),
        );
        exhausted.service.spawnCollectiblesForChunk(
          chunkIndex: 0,
          chunkStartX: 0,
          solids: const <StaticSolid>[],
        );
        expect(exhausted.world.collectible.denseEntities, isEmpty);
      },
    );

    test('restoration items use the same terrain placement boundary', () {
      final harness = _spawnHarness(
        seed: 77,
        geometry: _compile(<TerrainPolygonInput>[
          _rectangle('floor', 0, 300, 2048, 500),
        ]),
        collectibleTuning: const CollectibleTuning(enabled: false),
        restorationTuning: const RestorationItemTuning(
          spawnEveryChunks: 1,
          spawnStartChunkIndex: 0,
          maxAttemptsPerSpawn: 1,
        ),
      );

      harness.service.spawnRestorationItemForChunk(
        chunkIndex: 0,
        chunkStartX: 0,
        solids: const <StaticSolid>[],
        lowestResourceStat: () => RestorationStat.health,
      );

      expect(harness.world.restorationItem.denseEntities, hasLength(1));
      final item = harness.world.restorationItem.denseEntities.single;
      final transform = harness.world.transform.indexOf(item);
      expect(harness.world.transform.posY[transform], 282);
    });

    test('canonical results ignore polygon input order', () {
      expect(
        buildTerrainSpawnPlacementSignature(reverseInputOrder: true),
        buildTerrainSpawnPlacementSignature(),
      );
    });

    test('canonical results repeat in fresh Dart processes', () {
      List<Object?> runFreshProcess() {
        final result = Process.runSync(Platform.resolvedExecutable, <String>[
          'run',
          'test/helpers/print_terrain_spawn_placement_signature.dart',
        ], workingDirectory: Directory.current.path);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        return jsonDecode(result.stdout.toString().trim()) as List<Object?>;
      }

      expect(runFreshProcess(), runFreshProcess());
    });
  });
}

typedef _PlacementFixture = ({
  TerrainGeometry geometry,
  List<TerrainNavigationSurface> surfaces,
  TerrainSpawnPlacementResolver resolver,
});

typedef _SpawnHarness = ({EcsWorld world, SpawnService service});

_PlacementFixture _fixture(List<TerrainPolygonInput> inputs) {
  final geometry = _compile(inputs);
  final surfaceSet = const TerrainSurfaceExtractor().extract(geometry);
  return (
    geometry: geometry,
    surfaces: surfaceSet.surfaces,
    resolver: TerrainSpawnPlacementResolver(
      placementQuery: TerrainPlacementQuery(
        geometry: geometry,
        terrainIndex: TerrainEdgeIndex(edges: geometry.edges),
        surfaceIndex: TerrainSurfaceSpatialIndex(surfaceSet: surfaceSet),
      ),
    ),
  );
}

TerrainNavigationSurface _surface(_PlacementFixture fixture, String shapeId) =>
    fixture.surfaces.singleWhere((surface) => surface.id.shapeId == shapeId);

TerrainSpawnPlacementResult _enemyPlacement(
  _PlacementFixture fixture, {
  required EnemyId enemyId,
  required double x,
  required TerrainSpawnSupportSelection selection,
  double? requestedSupportY,
  TerrainNavigationSurface? intendedSupport,
  bool allowSameSupportClamp = false,
}) {
  const catalog = EnemyCatalog();
  final collider = catalog.get(enemyId).collider;
  final legacyY = (requestedSupportY ?? 0) - collider.offsetY - collider.halfY;
  return fixture.resolver.resolve(
    TerrainSpawnPlacementRequest(
      profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: catalog,
        enemyId: enemyId,
        facing: Facing.left,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(x, legacyY),
      supportSelection: selection,
      requestedSupportYTicks: requestedSupportY == null
          ? null
          : _ticks(requestedSupportY),
      intendedSupportEdgeId: intendedSupport?.id,
      allowSameSupportClamp: allowSameSupportClamp,
    ),
  );
}

TerrainSpawnPlacementResult _flyingPlacement(
  _PlacementFixture fixture, {
  required double x,
  required double y,
  TerrainSpawnSupportSelection selection = TerrainSpawnSupportSelection.none,
  double? requestedSupportY,
  bool intendedSourceAvailable = true,
}) => fixture.resolver.resolve(
  TerrainSpawnPlacementRequest(
    profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
      catalog: const EnemyCatalog(),
      enemyId: EnemyId.unocoDemon,
      facing: Facing.left,
    ),
    desiredBodyCenter: TerrainPoint.fromWorld(x, y),
    supportSelection: selection,
    requestedSupportYTicks: requestedSupportY == null
        ? null
        : _ticks(requestedSupportY),
    intendedSourceAvailable: intendedSourceAvailable,
  ),
);

TerrainSpawnPlacementResult _itemPlacement(
  _PlacementFixture fixture, {
  required double x,
  TerrainNavigationSurface? intendedSupport,
  TerrainItemSpawnPlacementProfile? profile,
}) => fixture.resolver.resolve(
  TerrainSpawnPlacementRequest(
    profile: profile ?? _itemProfile(),
    desiredBodyCenter: TerrainPoint.fromWorld(x, 0),
    supportSelection: TerrainSpawnSupportSelection.highestSurfaceAtX,
    intendedSupportEdgeId: intendedSupport?.id,
  ),
);

TerrainItemSpawnPlacementProfile _itemProfile({double supportClearance = 10}) =>
    TerrainItemSpawnPlacementProfile.fromWorld(
      itemKind: TerrainSpawnItemKind.collectible,
      width: 16,
      height: 16,
      supportClearance: supportClearance,
      noSpawnMargin: 2,
      traversalProfile: _playerArchetype().terrainTraversalProfile,
    );

_SpawnHarness _spawnHarness({
  required int seed,
  required TerrainGeometry geometry,
  required CollectibleTuning collectibleTuning,
  RestorationItemTuning restorationTuning = const RestorationItemTuning(
    enabled: false,
  ),
}) {
  final world = EcsWorld(seed: seed);
  final player = _playerArchetype();
  return (
    world: world,
    service: SpawnService(
      world: world,
      entityFactory: EntityFactory(world),
      enemyCatalog: const EnemyCatalog(),
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
      movement: MovementTuningDerived.from(
        eloiseCharacter.tuning.movement,
        tickHz: 60,
      ),
      collectibleTuning: collectibleTuning,
      restorationItemTuning: restorationTuning,
      trackTuning: const TrackTuning(
        chunkWidth: 2048,
        gridSnap: 1,
        playerStartX: 100,
      ),
      worldMotionAuthority: TerrainMultiBodyWorldMotionAuthority(
        geometry: geometry,
        playerProfile: player.terrainTraversalProfile,
      ),
      playerTerrainTraversalProfile: player.terrainTraversalProfile,
      seed: seed,
    ),
  );
}

List<double> _collectibleCandidateXs(int seed, {required int attemptCount}) {
  const salt = 0xC011EC7;
  var state = seedFrom(seed, salt);
  state = nextUint32(state); // Target-count draw remains first.
  return List<double>.generate(attemptCount, (_) {
    state = nextUint32(state);
    return rangeDouble(state, 32, 2016).roundToDouble();
  });
}

PlayerArchetype _playerArchetype() {
  final movement = MovementTuningDerived.from(
    eloiseCharacter.tuning.movement,
    tickHz: 60,
  );
  return PlayerCatalogDerived.from(
    eloiseCharacter.catalog,
    movement: movement,
    resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
  ).archetype;
}

TerrainGeometry _compile(List<TerrainPolygonInput> polygons) =>
    const TerrainCompiler().compile(polygons, geometryVersion: 20);

TerrainPolygonInput _rectangle(
  String shapeId,
  double left,
  double top,
  double right,
  double bottom, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
  String? surfaceKind,
}) => _polygon(
  shapeId,
  <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
  collisionMode: collisionMode,
  surfaceKind: surfaceKind,
);

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
  String? surfaceKind,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/$shapeId.json',
  identity: TerrainSourceIdentity(
    chunkIndex: 0,
    chunkKey: 'spawn-placement',
    shapeId: shapeId,
  ),
  vertices: vertices,
  collisionMode: collisionMode,
  surfaceKind: surfaceKind,
);

int _ticks(double world) => physicsCoordinateToTicks(world);
