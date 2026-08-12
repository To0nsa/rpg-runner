import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/enemies/hashash_teleport_state_store.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/enemy_cull_system.dart';
import 'package:runner_core/ecs/systems/enemy_death_state_system.dart';
import 'package:runner_core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/hashash_teleport_ambush_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/death_behavior.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/terrain_runtime_bundle.dart';
import 'package:runner_core/navigation/terrain_placement_query.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/navigation/terrain_surface_navigator.dart';
import 'package:runner_core/navigation/terrain_trajectory_predictor.dart';
import 'package:runner_core/navigation/types/surface_id.dart';
import 'package:runner_core/navigation/types/terrain_surface_graph.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_archetype.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enemy_terrain_signatures.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:runner_core/tuning/track_tuning.dart';

import 'slopes_golden_fixture.dart';
import 'terrain_spawn_placement_fixture.dart';

const int enemyTerrainRunSeed = 0x3E71;

/// Builds all SG-E01 through SG-E15 records from deterministic Core probes.
EnemyTerrainRunSignatureInput buildEnemyTerrainRunFixture({
  bool reverseInputOrder = false,
}) {
  final masterInputs = buildSlopesGoldenInputs();
  final masterGeometry = const TerrainCompiler().compile(
    reverseInputOrder ? masterInputs.reversed : masterInputs,
    geometryVersion: 23,
  );
  final masterBundle = TerrainRuntimeBundle.build(
    geometry: masterGeometry,
    groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
  );
  final scenarios = <EnemyTerrainScenarioSignatureInput>[
    _scenarioE01(reverseInputOrder),
    _scenarioE02(reverseInputOrder),
    _scenarioE03(reverseInputOrder),
    _scenarioE04(reverseInputOrder),
    _scenarioE05(reverseInputOrder),
    _scenarioE06(reverseInputOrder),
    _scenarioE07(reverseInputOrder),
    _scenarioE08(reverseInputOrder),
    _scenarioE09(reverseInputOrder),
    _scenarioE10(reverseInputOrder),
    _scenarioE11(reverseInputOrder),
    _scenarioE12(reverseInputOrder),
    _scenarioE13(reverseInputOrder),
    _scenarioE14(reverseInputOrder),
    _scenarioE15(),
  ];
  return EnemyTerrainRunSignatureInput(
    surfaceSignature: masterBundle.surfaceSignature(),
    graphSignature: masterBundle.graphSignature(),
    scenarios: reverseInputOrder ? scenarios.reversed.toList() : scenarios,
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE01(bool reverse) {
  final geometry = _compile(<TerrainPolygonInput>[
    _ground('flat-45-flat', const <(double, double)>[
      (0, 700),
      (220, 700),
      (420, 500),
      (620, 500),
    ]),
  ], reverse: reverse);
  final harness = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.grojib,
    enemyX: 120,
    enemySupportY: 700,
    speedX: 300,
  );
  harness.settle();
  var airborneTicks = 0;
  harness.run(
    160,
    targets: <int, double>{harness.enemies.single: 560},
    onTick: () {
      if (!harness.grounded(harness.enemies.single)) airborneTicks += 1;
    },
  );
  final right = harness.checkpoint(harness.enemies.single);
  harness.run(
    160,
    targets: <int, double>{harness.enemies.single: 120},
    onTick: () {
      if (!harness.grounded(harness.enemies.single)) airborneTicks += 1;
    },
  );
  final left = harness.checkpoint(harness.enemies.single);
  _ensure(airborneTicks == 0, 'SG-E01 lost support');
  _ensure(right.bodyXTicks > _ticks(500), 'SG-E01 did not traverse right');
  _ensure(left.bodyXTicks < _ticks(260), 'SG-E01 did not traverse left');
  return _scenario(
    id: 'SG-E01',
    fixture: 'flat-45-flat-v1',
    profiles: const <String>['grojib'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'grojib',
        kind: 'pursue-right',
        value0: 160,
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 161,
        order: 0,
        actorProfile: 'grojib',
        kind: 'pursue-left',
        value0: 160,
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[right, left],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'airborne-ticks',
        value: airborneTicks,
      ),
      const EnemyTerrainOutcomeSignatureRecord(
        key: 'directions-completed',
        value: 2,
      ),
    ],
    legacy: 'legacy-flat-graph-covered-separately',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE02(bool reverse) {
  final geometry = _compile(<TerrainPolygonInput>[
    _polygon('steep-route', const <(double, double)>[
      (0, 3000),
      (1120, 1060),
      (1400, 3600),
      (0, 3600),
    ]),
  ], reverse: reverse);
  final bundle = TerrainRuntimeBundle.build(
    geometry: geometry,
    groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
  );
  final steepIndex = bundle.surfaceSet.surfaces.indexWhere(
    (surface) => surface.id.shapeId == 'steep-route',
  );
  _ensure(steepIndex >= 0, 'SG-E02 lost its steep surface');
  final grojibEligible = bundle.grojibGraph.eligibility[steepIndex];
  final hashashEligible = bundle.hashashGraph.eligibility[steepIndex];
  final harness = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.hashash,
    enemyX: 300,
    enemySupportY: 2480.5,
    speedX: 300,
  )..settle();
  harness.run(180, targets: <int, double>{harness.enemies.single: 900});
  final hashash = harness.checkpoint(harness.enemies.single);
  _ensure(
    !grojibEligible && hashashEligible,
    'SG-E02 profile graph eligibility did not diverge',
  );
  _ensure(hashash.grounded, 'SG-E02 Hashash did not retain support');
  return _scenario(
    id: 'SG-E02',
    fixture: 'shared-60-route-v1',
    profiles: const <String>['grojib', 'hashash'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'both',
        kind: 'pursue-right',
        value0: 180,
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[hashash],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'grojib-route-accepted',
        value: grojibEligible ? 1 : 0,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'hashash-route-accepted',
        value: hashashEligible ? 1 : 0,
      ),
    ],
    legacy: 'legacy-horizontal-graph-has-no-slope-policy',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE03(bool reverse) {
  final checkpoints = <EnemyTerrainCheckpointSignatureRecord>[];
  final outcomes = <EnemyTerrainOutcomeSignatureRecord>[];
  for (final enemyId in const <EnemyId>[EnemyId.grojib, EnemyId.hashash]) {
    for (final delta in const <int>[4, 5]) {
      bool exerciseHelper({required bool drop}) {
        final harness = _MotionHarness.one(
          geometry: drop
              ? _dropGeometry(delta, reverse: reverse)
              : _stepGeometry(delta, reverse: reverse),
          enemyId: enemyId,
          enemyX: 250,
          enemySupportY: 500,
          speedX: 120,
        )..settle();
        final enemy = harness.enemies.single;
        var acceptedTransition = false;
        for (var tick = 0; tick < 45; tick += 1) {
          final contact = harness.world.terrainContact.indexOf(enemy);
          final priorShape =
              harness.world.terrainContact.supportEdgeId[contact]?.shapeId;
          harness.step(targetX: 650);
          final nextShape =
              harness.world.terrainContact.supportEdgeId[contact]?.shapeId;
          final used = drop
              ? harness.world.terrainContact.usedSnap[contact]
              : harness.world.terrainContact.usedStep[contact];
          acceptedTransition |=
              used &&
              priorShape?.endsWith('-left') == true &&
              nextShape?.endsWith('-right') == true;
        }
        checkpoints.add(harness.checkpoint(enemy));
        return acceptedTransition;
      }

      final usedStep = exerciseHelper(drop: false);
      final usedSnap = exerciseHelper(drop: true);
      if (delta == 4) {
        _ensure(
          usedStep && usedSnap,
          'SG-E03 valid helper failed for ${enemyId.name}: '
          'step=$usedStep snap=$usedSnap',
        );
      } else {
        _ensure(
          !usedStep && !usedSnap,
          'SG-E03 five-pixel helper passed for ${enemyId.name}: '
          'step=$usedStep snap=$usedSnap',
        );
      }
      outcomes.add(
        EnemyTerrainOutcomeSignatureRecord(
          key: '${enemyId.name}-step-$delta',
          value: usedStep ? 1 : 0,
        ),
      );
      outcomes.add(
        EnemyTerrainOutcomeSignatureRecord(
          key: '${enemyId.name}-snap-$delta',
          value: usedSnap ? 1 : 0,
        ),
      );
    }
  }
  return _scenario(
    id: 'SG-E03',
    fixture: 'step-snap-4-vs-5-v1',
    profiles: const <String>['grojib', 'hashash'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'both',
        kind: 'step-and-snap-right',
        value0: 4,
        value1: 5,
      ),
    ],
    checkpoints: checkpoints,
    outcomes: outcomes,
    legacy: 'legacy-step-policy-characterized-in-root-tests',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE04(bool reverse) {
  final geometry = _compile(<TerrainPolygonInput>[
    _ground('left', const <(double, double)>[
      (0, 600),
      (240, 600),
    ], chunkIndex: 0),
    _ground('peak-valley', const <(double, double)>[
      (240, 600),
      (360, 520),
      (480, 600),
      (600, 520),
      (720, 600),
    ], chunkIndex: 1),
    _ground('right', const <(double, double)>[
      (720, 600),
      (1000, 600),
    ], chunkIndex: 2),
  ], reverse: reverse);
  final harness = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.grojib,
    enemyX: 120,
    enemySupportY: 600,
    speedX: 360,
  );
  harness.settle();
  var reversals = 0;
  var previousSign = 0;
  harness.run(
    180,
    targets: <int, double>{harness.enemies.single: 900},
    onTick: () {
      if (harness.bodyX(harness.enemies.single) >= 800) return;
      final sign = harness.velocityX(harness.enemies.single).sign.toInt();
      if (previousSign != 0 && sign != 0 && sign != previousSign) {
        reversals += 1;
      }
      if (sign != 0) previousSign = sign;
    },
  );
  final checkpoint = harness.checkpoint(harness.enemies.single);
  _ensure(
    checkpoint.bodyXTicks > _ticks(800),
    'SG-E04 did not cross the chain',
  );
  _ensure(reversals == 0, 'SG-E04 oscillated');
  return _scenario(
    id: 'SG-E04',
    fixture: 'peak-valley-seams-v1',
    profiles: const <String>['grojib'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'grojib',
        kind: 'same-chain-pursuit',
        value0: 180,
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[checkpoint],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'direction-reversals',
        value: reversals,
      ),
    ],
    legacy: 'legacy-seam-pursuit-remains-production-until-phase-5',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE05(bool reverse) {
  final bundle = _bundle(<TerrainPolygonInput>[
    _polygon('lower', const <(double, double)>[
      (-100, 130),
      (300, 110),
      (300, 140),
      (-100, 140),
    ]),
    _rectangle('upper', 40, 60, 160, 90, chunkIndex: 1),
  ], reverse: reverse);
  int count(TerrainSurfaceGraph graph, TerrainSurfaceEdgeKind kind) =>
      graph.edges.where((edge) => edge.kind == kind).length;
  final jumpCount = count(bundle.hashashGraph, TerrainSurfaceEdgeKind.jump);
  final dropCount = count(bundle.hashashGraph, TerrainSurfaceEdgeKind.drop);
  _ensure(jumpCount > 0, 'SG-E05 emitted no jump');
  _ensure(dropCount > 0, 'SG-E05 emitted no drop');
  ({TerrainSurfaceGraphEdge edge, TerrainEdgeId destination}) firstEdge(
    TerrainSurfaceEdgeKind kind,
  ) {
    final graph = bundle.hashashGraph;
    for (var source = 0; source < graph.surfaces.length; source += 1) {
      for (final edge in graph.edgesFor(source)) {
        if (edge.kind == kind) {
          return (edge: edge, destination: graph.surfaces[edge.to].id);
        }
      }
    }
    throw StateError('SG-E05 missing ${kind.name} edge');
  }

  TerrainLandingPrediction replay(TerrainSurfaceGraphEdge edge) {
    final graphProfile = bundle.hashashGraph.buildProfile;
    final jump = graphProfile.jumpTemplate.profile;
    final result = TerrainLandingPrediction();
    final predicted =
        TerrainTrajectoryPredictor(
          placementQuery: TerrainPlacementQuery(
            geometry: bundle.geometry,
            terrainIndex: bundle.edgeIndex,
            surfaceIndex: bundle.surfaceIndex,
          ),
          traversalProfile: graphProfile.traversalProfile,
          supportRequirement: graphProfile.supportRequirement,
          dtSeconds: jump.dtSeconds,
          maxTicks: jump.maxAirTicks,
        ).predictLanding(
          startBodyCenter: edge.takeoffPoint,
          capsule: graphProfile.capsuleForDirection(edge.commitDirectionX),
          velocityX: edge.commitDirectionX * jump.airSpeedX,
          velocityY: edge.kind == TerrainSurfaceEdgeKind.jump
              ? -jump.jumpSpeed
              : 0,
          gravityY: jump.gravityY,
          maximumFallSpeed: 20000,
          out: result,
        );
    _ensure(predicted, 'SG-E05 ${edge.kind.name} replay found no landing');
    return result;
  }

  final jumpEdge = firstEdge(TerrainSurfaceEdgeKind.jump);
  final dropEdge = firstEdge(TerrainSurfaceEdgeKind.drop);
  final jumpLanding = replay(jumpEdge.edge);
  _ensure(
    jumpLanding.supportEdgeId == jumpEdge.destination,
    'SG-E05 jump replay landed on the wrong support',
  );
  _ensure(
    dropEdge.edge.travelTicks > 0 &&
        dropEdge.edge.landingPoint.yTicks > dropEdge.edge.takeoffPoint.yTicks,
    'SG-E05 drop edge has no executable descent',
  );
  return _scenario(
    id: 'SG-E05',
    fixture: 'sloped-jump-drop-v1',
    profiles: const <String>['grojib', 'hashash'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 0,
        order: 0,
        actorProfile: 'hashash',
        kind: 'build-air-edges',
      ),
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'jump-edge-count',
        value: jumpCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'drop-edge-count',
        value: dropCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'graph-record-count',
        value: bundle.graphPublication.canonicalRecords().length,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'jump-replay-ticks',
        value: jumpLanding.ticksToLand,
        code: jumpLanding.supportEdgeId?.canonicalKey ?? '',
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'drop-replay-ticks',
        value: dropEdge.edge.travelTicks,
        code: dropEdge.destination.canonicalKey,
      ),
    ],
    legacy: 'legacy-jump-drop-templates-remain-production',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE06(bool reverse) {
  final bundle = _bundle(<TerrainPolygonInput>[
    _ground('floor', const <(double, double)>[(0, 300), (500, 300)]),
    _polygon('wall', const <(double, double)>[
      (220, 80),
      (230, 80),
      (230, 300),
      (220, 300),
    ], chunkIndex: 1),
    _polygon('ceiling', const <(double, double)>[
      (40, 120),
      (180, 120),
      (180, 140),
      (40, 140),
    ], chunkIndex: 2),
    _polygon(
      'one-way',
      const <(double, double)>[(260, 220), (420, 180), (420, 190), (260, 230)],
      chunkIndex: 3,
      collisionMode: TerrainCollisionMode.oneWay,
    ),
  ], reverse: reverse);
  final oneWayCount = bundle.surfaceSet.surfaces
      .where((surface) => surface.collisionMode == TerrainCollisionMode.oneWay)
      .length;
  final verticalWallIds = bundle.geometry.edges
      .where((edge) => edge.id.shapeId == 'wall' && edge.dxTicks == 0)
      .map((edge) => edge.id)
      .toSet();
  final verticalWallSurfaceCount = bundle.surfaceSet.surfaces
      .where((surface) => verticalWallIds.contains(surface.id))
      .length;
  _ensure(oneWayCount > 0, 'SG-E06 lost one-way support');
  _ensure(
    verticalWallSurfaceCount == 0,
    'SG-E06 exposed a vertical wall as support',
  );
  return _scenario(
    id: 'SG-E06',
    fixture: 'solid-one-way-mask-v1',
    profiles: const <String>['grojib', 'hashash', 'unocoDemon'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 0,
        order: 0,
        actorProfile: 'all',
        kind: 'compile-policy-views',
      ),
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'one-way-surface-count',
        value: oneWayCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'vertical-wall-nav-count',
        value: verticalWallSurfaceCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'solid-edge-count',
        value: bundle.geometry.edges
            .where((edge) => edge.collisionMode == TerrainCollisionMode.solid)
            .length,
      ),
    ],
    legacy: 'legacy-mask-semantics-covered-by-existing-root-tests',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE07(bool reverse) {
  final bundle = _bundle(<TerrainPolygonInput>[
    _ground('left', const <(double, double)>[(0, 300), (220, 300)]),
    _ground('right', const <(double, double)>[
      (220, 300),
      (500, 260),
    ], chunkIndex: 1),
    _ground('landing', const <(double, double)>[
      (600, 360),
      (820, 320),
    ], chunkIndex: 2),
  ], reverse: reverse);
  final state = TerrainSurfaceNavigatorState()
    ..bundleVersion = 1
    ..currentSurfaceId = bundle.surfaceSet.surfaces.first.id
    ..currentSurfaceIndex = 0
    ..lastGroundSurfaceId = bundle.surfaceSet.surfaces.first.id
    ..lastGroundSurfaceIndex = 0
    ..targetSurfaceId = bundle.surfaceSet.surfaces.last.id
    ..targetSurfaceIndex = bundle.surfaceSet.surfaces.length - 1
    ..activeEdgeIndex = 0
    ..pathCursor = 1
    ..pathEdges.addAll(<int>[0, 1]);
  state.invalidateForBundle(2);
  const catalog = EnemyCatalog();
  final hashashContact = catalog.terrainContactProfile(EnemyId.hashash);
  final hashashSpawn = TerrainEnemySpawnPlacementProfile.fromCatalog(
    catalog: catalog,
    enemyId: EnemyId.hashash,
    facing: Facing.right,
  );
  final prediction = TerrainLandingPrediction();
  final predicted =
      TerrainTrajectoryPredictor(
        placementQuery: TerrainPlacementQuery(
          geometry: bundle.geometry,
          terrainIndex: bundle.edgeIndex,
          surfaceIndex: bundle.surfaceIndex,
        ),
        traversalProfile: hashashContact.traversal,
        supportRequirement:
            const TerrainSupportRequirement.groundedEnemyRuntime(),
        dtSeconds: 1 / 60,
        maxTicks: 120,
      ).predictLanding(
        startBodyCenter: TerrainPoint.fromWorld(500, 100),
        capsule: hashashSpawn.capsule,
        velocityX: 200,
        velocityY: 0,
        gravityY: const PhysicsTuning().gravityY,
        maximumFallSpeed: 20000,
        out: prediction,
      );
  _ensure(
    state.currentSurfaceId == null && state.targetSurfaceId == null,
    'SG-E07 retained stale surfaces',
  );
  _ensure(
    state.pathEdges.isEmpty && state.activeEdgeIndex == -1,
    'SG-E07 retained stale path',
  );
  _ensure(
    predicted && prediction.supportEdgeId?.shapeId == 'landing',
    'SG-E07 airborne prediction missed the landing support',
  );
  return _scenario(
    id: 'SG-E07',
    fixture: 'target-seam-airborne-invalidation-v1',
    profiles: const <String>['grojib', 'hashash', 'player-target'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'player-target',
        kind: 'cross-seam-then-airborne',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 2,
        order: 0,
        actorProfile: 'both',
        kind: 'publish-version-2',
      ),
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'surface-count',
        value: bundle.surfaceSet.surfaces.length,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'invalidated-version',
        value: state.bundleVersion,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'remaining-path-edges',
        value: state.pathEdges.length,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'prediction-ticks-to-land',
        value: prediction.ticksToLand,
        code: prediction.supportEdgeId?.canonicalKey ?? '',
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'prediction-body-x-ticks',
        value: prediction.bodyCenterXTicks,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'prediction-body-y-ticks',
        value: prediction.bodyCenterYTicks,
      ),
    ],
    legacy: 'terrain-target-prediction-remains-isolated-until-phase-5',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE08(bool reverse) {
  final primary = _TeleportHarness.create(
    geometry: _compile(<TerrainPolygonInput>[
      _rectangle('teleport-narrow-floor', 270, 500, 330, 600),
    ], reverse: reverse),
  )..resolve();
  final mirror = _TeleportHarness.create(
    geometry: _teleportBlockerGeometry(const <String>[
      'wall-primary',
    ], reverse: reverse),
  )..resolve();
  final canceled = <_TeleportHarness>[
    for (final kind in const <String>['wall', 'ceiling', 'slope', 'concave'])
      _TeleportHarness.create(
        geometry: _teleportBlockerGeometry(<String>[
          '$kind-primary',
          '$kind-mirror',
        ], reverse: reverse),
      )..resolve(),
  ];
  _ensure(
    primary.phase == HashashTeleportPhase.ambush,
    'SG-E08 primary failed',
  );
  _ensure(mirror.phase == HashashTeleportPhase.ambush, 'SG-E08 mirror failed');
  _ensure(
    canceled.every((probe) => probe.phase == HashashTeleportPhase.idle),
    'SG-E08 cancellation matrix failed',
  );
  return _scenario(
    id: 'SG-E08',
    fixture: 'hashash-teleport-transaction-v1',
    profiles: const <String>['hashash'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: _TeleportHarness.resolutionTick,
        order: 0,
        actorProfile: 'hashash',
        kind: 'try-primary-then-mirror-then-cancel',
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[
      primary.checkpoint('primary-committed'),
      mirror.checkpoint('mirror-committed'),
      canceled.first.checkpoint('canceled-restored'),
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      const EnemyTerrainOutcomeSignatureRecord(
        key: 'primary-commit-count',
        value: 1,
      ),
      const EnemyTerrainOutcomeSignatureRecord(
        key: 'mirror-commit-count',
        value: 1,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'cancel-kind-count',
        value: canceled.length,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'cancel-rng-preserved-count',
        value: canceled.where((probe) => probe.rngState == 0x12345678).length,
      ),
    ],
    legacy: 'legacy-unchecked-teleport-is-retired-for-terrain-bodies',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE09(bool reverse) {
  final hover = _FlyingHarness.create(
    geometry: _compile(<TerrainPolygonInput>[
      _ground('unoco-slope', const <(double, double)>[(0, 500), (1000, 300)]),
      _playerSpawnPolygon(),
    ], reverse: reverse),
    enemyX: 500,
    enemyY: 350,
    playerX: 550,
  )..configureHover(height: 100, desiredRange: 50);
  hover.stepLocomotion();

  final blocked = _FlyingHarness.create(
    geometry: _compile(<TerrainPolygonInput>[
      _rectangle('unoco-wall', 300, 0, 301, 600),
      _playerSpawnPolygon(),
    ], reverse: reverse),
    enemyX: 200,
    enemyY: 250,
    playerX: 900,
  )..stepMotion(velocityX: 12000, velocityY: 0);

  final oneWay = _FlyingHarness.create(
    geometry: _compile(<TerrainPolygonInput>[
      _rectangle(
        'unoco-one-way',
        0,
        300,
        600,
        310,
        collisionMode: TerrainCollisionMode.oneWay,
      ),
      _playerSpawnPolygon(),
    ], reverse: reverse),
    enemyX: 200,
    enemyY: 200,
    playerX: 900,
  )..stepMotion(velocityX: 0, velocityY: 12000);

  final clearance = _FlyingHarness.create(
    geometry: _compile(<TerrainPolygonInput>[
      _rectangle('unoco-detour-floor', 0, 480, 1000, 700),
      _rectangle('unoco-detour-wall', 300, 250, 320, 480),
      _playerSpawnPolygon(),
    ], reverse: reverse),
    enemyX: 200,
    enemyY: 300,
    playerX: 700,
    groundTopY: 480,
    tuning: const UnocoDemonTuning(
      unocoDemonAccelX: 18000,
      unocoDemonDecelX: 18000,
      unocoDemonVerticalDeadzone: 0,
    ),
  )..configureHover(height: 180, desiredRange: 50);
  var clearanceSelections = 0;
  for (var tick = 0; tick < 180; tick += 1) {
    clearance.stepLocomotion();
    if (clearance.clearanceCandidateId > 0) clearanceSelections += 1;
  }
  _ensure(hover.hasLocalTerrainReference, 'SG-E09 lost local hover reference');
  _ensure(blocked.blockingContactCount > 0, 'SG-E09 crossed a solid wall');
  _ensure(oneWay.blockingContactCount == 0, 'SG-E09 blocked on one-way');
  _ensure(clearanceSelections > 0, 'SG-E09 never selected clearance');
  return _scenario(
    id: 'SG-E09',
    fixture: 'unoco-terrain-flight-v1',
    profiles: const <String>['unocoDemon'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'unocoDemon',
        kind: 'sample-local-hover',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 1,
        actorProfile: 'unocoDemon',
        kind: 'sweep-solid-and-one-way',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 2,
        order: 0,
        actorProfile: 'unocoDemon',
        kind: 'bounded-clearance-steering',
        value0: 180,
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[
      hover.checkpoint(),
      blocked.checkpoint(),
      oneWay.checkpoint(),
      clearance.checkpoint(),
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'hover-reference-y-ticks',
        value: _ticks(hover.effectiveFlightReferenceY),
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'solid-contact-count',
        value: blocked.blockingContactCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'one-way-contact-count',
        value: oneWay.blockingContactCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'clearance-selection-ticks',
        value: clearanceSelections,
      ),
    ],
    legacy: 'legacy-flight-ground-plane-remains-fallback-only',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE10(bool reverse) {
  final flat = _resolveDerfPlacement(
    _compile(<TerrainPolygonInput>[
      _rectangle('derf-flat', 0, 300, 112, 400),
    ], reverse: reverse),
    x: 56,
    supportY: 300,
  );
  final gentle = _resolveDerfPlacement(
    _compile(<TerrainPolygonInput>[
      _polygon('derf-15', const <(double, double)>[
        (0, 300),
        (112, 270),
        (112, 400),
        (0, 400),
      ]),
    ], reverse: reverse),
    x: 56,
    supportY: 285,
  );
  final steep = _resolveDerfPlacement(
    _compile(<TerrainPolygonInput>[
      _polygon('derf-over-15', const <(double, double)>[
        (0, 300),
        (112, 269),
        (112, 400),
        (0, 400),
      ]),
    ], reverse: reverse),
    x: 56,
    supportY: 284.5,
  );
  _ensure(flat.accepted && gentle.accepted, 'SG-E10 valid perch rejected');
  _ensure(!steep.accepted, 'SG-E10 invalid perch accepted');
  final flatCast = _castDerf(flat);
  final slopeCast = _castDerf(gentle);
  _ensure(flatCast.abilityId == slopeCast.abilityId, 'SG-E10 cast changed');
  _ensure(
    flatCast.targetXTicks == slopeCast.targetXTicks &&
        flatCast.targetYTicks == slopeCast.targetYTicks &&
        flatCast.executeTick == slopeCast.executeTick,
    'SG-E10 target semantics changed',
  );
  return _scenario(
    id: 'SG-E10',
    fixture: 'derf-perch-cast-v1',
    profiles: const <String>['derf'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 0,
        order: 0,
        actorProfile: 'derf',
        kind: 'resolve-flat-gentle-steep-perches',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 10,
        order: 0,
        actorProfile: 'derf',
        kind: 'commit-primary-cast',
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[slopeCast.checkpoint],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'flat-placement',
        value: flat.accepted ? 1 : 0,
        code: flat.validity.name,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'gentle-placement',
        value: gentle.absoluteSlopeAngleUnits ?? -1,
        code: gentle.validity.name,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'steep-placement',
        value: steep.accepted ? 1 : 0,
        code: steep.validity.name,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'cast-execute-tick',
        value: slopeCast.executeTick,
        code: slopeCast.abilityId,
      ),
    ],
    legacy: 'legacy-derf-cast-and-presentation-semantics-preserved',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE11(bool reverse) {
  final diagnostics = buildTerrainSpawnPlacementSignature(
    reverseInputOrder: reverse,
  );
  _ensure(diagnostics.length == 4, 'SG-E11 placement matrix is incomplete');
  _ensure(
    diagnostics.every(
      (record) => record.startsWith('terrain-spawn-placement-v1|'),
    ),
    'SG-E11 found an unversioned placement diagnostic',
  );
  return _scenario(
    id: 'SG-E11',
    fixture: 'shared-spawn-placement-v1',
    profiles: const <String>[
      'ground-enemy',
      'flying-enemy',
      'deferred-hashash',
      'item',
    ],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 0,
        order: 0,
        actorProfile: 'all',
        kind: 'resolve-without-extra-rng-draws',
      ),
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      for (var index = 0; index < diagnostics.length; index += 1)
        EnemyTerrainOutcomeSignatureRecord(
          key: 'placement-diagnostic-$index',
          code: diagnostics[index],
        ),
      const EnemyTerrainOutcomeSignatureRecord(
        key: 'replacement-rng-draws',
        value: 0,
      ),
    ],
    legacy: 'legacy-spawn-selection-order-and-failure-consumption-preserved',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE12(bool reverse) {
  final geometry = _compile(<TerrainPolygonInput>[
    _ground('lifecycle-floor', const <(double, double)>[(0, 700), (2000, 700)]),
  ], reverse: reverse);
  final locked = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.grojib,
    enemyX: 200,
    enemySupportY: 700,
    speedX: 240,
  )..settle();
  final lockedEnemy = locked.enemies.single;
  final beforeLock = locked.checkpoint(lockedEnemy);
  locked.world.controlLock.addLock(
    lockedEnemy,
    LockFlag.move | LockFlag.nav | LockFlag.stun,
    2,
    locked.tick,
  );
  locked.step(targetX: 1000);
  final afterLock = locked.checkpoint(lockedEnemy);

  final status = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.grojib,
    enemyX: 200,
    enemySupportY: 700,
    speedX: 240,
  )..settle();
  final statusEnemy = status.enemies.single;
  final modifierIndex = status.world.statModifier.indexOf(statusEnemy);
  status.world.statModifier.moveSpeedMul[modifierIndex] = 0.5;
  for (var tick = 0; tick < 30; tick += 1) {
    status.step(targetX: 1000, stateSpeedMul: 0.5);
  }
  final statusCheckpoint = status.checkpoint(statusEnemy);

  final landing = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.hashash,
    enemyX: 300,
    enemySupportY: 700,
    speedX: 240,
  )..settle();
  final landingEnemy = landing.enemies.single;
  landing.step(targetX: 1000, jumpNow: true, commitMoveDirX: 1);
  landing.world.health.hp[landing.world.health.indexOf(landingEnemy)] = 0;
  final death = EnemyDeathStateSystem(tickHz: 60);
  death.step(landing.world, currentTick: landing.tick);
  final landingDeathIndex = landing.world.deathState.indexOf(landingEnemy);
  for (
    var tick = 0;
    tick < 120 &&
        landing.world.deathState.phase[landingDeathIndex] ==
            DeathPhase.fallingUntilGround;
    tick += 1
  ) {
    landing.step(targetX: 1000);
    death.step(landing.world, currentTick: landing.tick);
  }
  final landingCheckpoint = _checkpoint(
    landing.world,
    enemy: landingEnemy,
    tick: landing.tick,
    lifecycleCode: landing.world.deathState.phase[landingDeathIndex].name,
  );

  final timeout = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.grojib,
    enemyX: 500,
    enemySupportY: 700,
    speedX: 240,
  )..settle();
  final timeoutEnemy = timeout.enemies.single;
  timeout.step(targetX: 1200, jumpNow: true, commitMoveDirX: 1);
  timeout.world.health.hp[timeout.world.health.indexOf(timeoutEnemy)] = 0;
  death.step(timeout.world, currentTick: timeout.tick);
  death.step(timeout.world, currentTick: timeout.tick + 180);
  final timeoutIndex = timeout.world.deathState.indexOf(timeoutEnemy);

  final culled = _MotionHarness.one(
    geometry: geometry,
    enemyId: EnemyId.grojib,
    enemyX: 100,
    enemySupportY: 700,
    speedX: 240,
  )..settle();
  final culledEnemy = culled.enemies.single;
  culled.world.transform.posX[culled.world.transform.indexOf(culledEnemy)] =
      -10000;
  const TrackTuning trackTuning = TrackTuning();
  EnemyCullSystem().step(
    culled.world,
    cameraLeft: 0,
    groundTopY: 700,
    tuning: trackTuning,
  );

  _ensure(
    afterLock.bodyXTicks == beforeLock.bodyXTicks,
    'SG-E12 lock allowed movement',
  );
  _ensure(
    statusCheckpoint.bodyXTicks > _ticks(200) &&
        statusCheckpoint.bodyXTicks < _ticks(260),
    'SG-E12 speed modifiers were not composed',
  );
  _ensure(
    landing.world.deathState.phase[landingDeathIndex] == DeathPhase.deathAnim,
    'SG-E12 landing death did not advance',
  );
  _ensure(
    timeout.world.deathState.phase[timeoutIndex] == DeathPhase.deathAnim,
    'SG-E12 death timeout did not advance',
  );
  _ensure(
    !culled.world.enemy.has(culledEnemy),
    'SG-E12 cull did not remove enemy',
  );
  return _scenario(
    id: 'SG-E12',
    fixture: 'locks-status-death-cull-v1',
    profiles: const <String>['grojib', 'hashash'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'grojib',
        kind: 'apply-move-nav-stun-locks',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 1,
        actorProfile: 'grojib',
        kind: 'compose-status-speed',
        value0: 5000,
        value1: 5000,
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 2,
        actorProfile: 'both',
        kind: 'resolve-death-landing-timeout-cull',
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[
      afterLock,
      statusCheckpoint,
      landingCheckpoint,
    ],
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'lock-active-mask',
        value: locked.world.controlLock.getActiveMask(lockedEnemy),
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'landing-death-phase',
        value: landing.world.deathState.phase[landingDeathIndex].index,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'timeout-death-phase',
        value: timeout.world.deathState.phase[timeoutIndex].index,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'culled-entity-present',
        value: culled.world.enemy.has(culledEnemy) ? 1 : 0,
      ),
    ],
    legacy: 'legacy-lock-status-death-and-cull-semantics-preserved',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE13(bool reverse) {
  final geometry = _compile(<TerrainPolygonInput>[
    _ground('mixed-floor', const <(double, double)>[(0, 900), (1600, 700)]),
    _playerSpawnPolygon(),
  ], reverse: reverse);
  final mixed = _MixedEnemyHarness.create(geometry: geometry);
  mixed.run(90);
  _ensure(mixed.groundEnemyCount == 16, 'SG-E13 ground count changed');
  _ensure(mixed.flyingEnemyCount == 4, 'SG-E13 flying count changed');
  _ensure(mixed.derfCount == 4, 'SG-E13 Derf count changed');
  _ensure(mixed.lastIntegratedBodyCount == 20, 'SG-E13 dispatch count changed');
  return _scenario(
    id: 'SG-E13',
    fixture: 'representative-mixed-enemies-v1',
    profiles: const <String>['grojib', 'hashash', 'unocoDemon', 'derf'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'all',
        kind: 'run-representative-mix',
        value0: 90,
      ),
    ],
    checkpoints: mixed.checkpoints(),
    outcomes: <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(
        key: 'ground-enemy-count',
        value: mixed.groundEnemyCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'flying-enemy-count',
        value: mixed.flyingEnemyCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'derf-count',
        value: mixed.derfCount,
      ),
      EnemyTerrainOutcomeSignatureRecord(
        key: 'integrated-body-count',
        value: mixed.lastIntegratedBodyCount,
      ),
    ],
    legacy: 'legacy-mixed-run-remains-production-until-phase-5-cutover',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE14(bool reverse) {
  final oldGeometry = _compile(
    <TerrainPolygonInput>[
      _ground('replace-floor', const <(double, double)>[(0, 700), (1200, 700)]),
    ],
    reverse: reverse,
    version: 23,
  );
  final newGeometry = _compile(
    <TerrainPolygonInput>[
      _ground('replace-floor', const <(double, double)>[(0, 700), (1200, 660)]),
    ],
    reverse: reverse,
    version: 24,
  );

  _MotionHarness make() => _MotionHarness.one(
    geometry: oldGeometry,
    enemyId: EnemyId.hashash,
    enemyX: 300,
    enemySupportY: 700,
    speedX: 240,
  )..settle();

  final grounded = make();
  grounded.authority.queueTerrainGeometryReplacement(newGeometry);
  grounded.step(targetX: 300);

  final navigating = make();
  final navigatingEnemy = navigating.enemies.single;
  final navIndex = navigating.world.surfaceNav.indexOf(navigatingEnemy);
  navigating.world.surfaceNav.graphVersion[navIndex] = 23;
  navigating.world.surfaceNav.currentSurfaceId[navIndex] = 0;
  navigating.world.surfaceNav.lastGroundSurfaceId[navIndex] = 0;
  navigating.world.surfaceNav.targetSurfaceId[navIndex] = 0;
  navigating.world.surfaceNav.activeEdgeIndex[navIndex] = 0;
  navigating.world.surfaceNav.pathEdges[navIndex].add(0);
  navigating.authority.queueTerrainGeometryReplacement(newGeometry);
  navigating.step(targetX: 900);

  final airborne = make();
  airborne.step(targetX: 900, jumpNow: true, commitMoveDirX: 1);
  airborne.authority.queueTerrainGeometryReplacement(newGeometry);
  airborne.step(targetX: 900);

  final groundedCheckpoint = grounded.checkpoint(grounded.enemies.single);
  final navigatingCheckpoint = navigating.checkpoint(navigatingEnemy);
  final airborneCheckpoint = airborne.checkpoint(airborne.enemies.single);
  _ensure(
    grounded.authority.terrainGeometryVersion == 24 &&
        navigating.authority.terrainGeometryVersion == 24 &&
        airborne.authority.terrainGeometryVersion == 24,
    'SG-E14 replacement was not atomic',
  );
  _ensure(
    navigatingCheckpoint.pathEdges.isEmpty,
    'SG-E14 retained a stale navigation path',
  );
  _ensure(!airborneCheckpoint.grounded, 'SG-E14 grounded the airborne actor');
  return _scenario(
    id: 'SG-E14',
    fixture: 'atomic-bundle-replacement-v1',
    profiles: const <String>['hashash'],
    schedule: const <EnemyTerrainScheduleSignatureRecord>[
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 0,
        actorProfile: 'grounded',
        kind: 'publish-version-24',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 1,
        order: 1,
        actorProfile: 'navigating',
        kind: 'publish-version-24',
      ),
      EnemyTerrainScheduleSignatureRecord(
        tick: 2,
        order: 0,
        actorProfile: 'airborne',
        kind: 'publish-version-24',
      ),
    ],
    checkpoints: <EnemyTerrainCheckpointSignatureRecord>[
      groundedCheckpoint,
      navigatingCheckpoint,
      airborneCheckpoint,
    ],
    outcomes: const <EnemyTerrainOutcomeSignatureRecord>[
      EnemyTerrainOutcomeSignatureRecord(key: 'published-version', value: 24),
      EnemyTerrainOutcomeSignatureRecord(key: 'publication-count', value: 3),
    ],
    legacy: 'legacy-static-geometry-has-no-stream-replacement-contract',
  );
}

EnemyTerrainScenarioSignatureInput _scenarioE15() => _scenario(
  id: 'SG-E15',
  fixture: 'fresh-process-parity-v1',
  profiles: const <String>['all-phase-3'],
  schedule: const <EnemyTerrainScheduleSignatureRecord>[
    EnemyTerrainScheduleSignatureRecord(
      tick: 0,
      order: 0,
      actorProfile: 'test-runner',
      kind: 'launch-two-fresh-processes',
      value0: 2,
    ),
  ],
  outcomes: const <EnemyTerrainOutcomeSignatureRecord>[
    EnemyTerrainOutcomeSignatureRecord(key: 'signature-schema-count', value: 3),
    EnemyTerrainOutcomeSignatureRecord(key: 'required-process-count', value: 2),
  ],
  legacy: 'fresh-process-proof-is-enforced-by-the-signature-test',
);

final class _TeleportHarness {
  _TeleportHarness._({
    required this.world,
    required this.player,
    required this.hashash,
    required this.authority,
  });

  static const int resolutionTick = 25;

  factory _TeleportHarness.create({required TerrainGeometry geometry}) {
    final world = EcsWorld(seed: enemyTerrainRunSeed);
    final playerArchetype = _playerArchetype();
    final factory = EntityFactory(world);
    final player = factory.createPlayer(
      posX: 300,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: playerArchetype.facing,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    const catalog = EnemyCatalog();
    final archetype = catalog.get(EnemyId.hashash);
    final safeBodyY =
        500 - archetype.collider.offsetY - archetype.collider.halfY;
    final hashash = factory.createEnemy(
      enemyId: EnemyId.hashash,
      posX: 100,
      posY: safeBodyY,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      artFacing: archetype.artFacingDir,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
      tags: archetype.tags,
      resistance: archetype.resistance,
      statusImmunity: archetype.statusImmunity,
    );
    final authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    authority.prepareTick(world, player: player, currentTick: resolutionTick);
    final profile = catalog.terrainContactProfile(EnemyId.hashash);
    world.terrainContact.setLastValidBodyPosition(
      hashash,
      xTicks: _ticks(100),
      yTicks: _ticks(safeBodyY),
    );
    world.terrainContact.setLastCapsuleState(
      hashash,
      centerXTicks: _ticks(100 + profile.capsule.offsetX),
      centerYTicks: _ticks(safeBodyY + profile.capsule.offsetY),
      facingSign: 1,
    );
    final navIndex = world.surfaceNav.indexOf(hashash);
    world.surfaceNav.graphVersion[navIndex] = geometry.version;
    world.surfaceNav.currentSurfaceId[navIndex] = 17;
    world.surfaceNav.lastGroundSurfaceId[navIndex] = 17;
    world.surfaceNav.targetSurfaceId[navIndex] = 18;
    world.surfaceNav.activeEdgeIndex[navIndex] = 0;
    world.surfaceNav.pathCursor[navIndex] = 1;
    world.surfaceNav.pathEdges[navIndex].addAll(const <int>[17, 18]);
    final teleportIndex = world.hashashTeleport.indexOf(hashash);
    world.hashashTeleport.phase[teleportIndex] = HashashTeleportPhase.evadeOut;
    world.hashashTeleport.phaseEndTick[teleportIndex] = resolutionTick;
    world.hashashTeleport.rngState[teleportIndex] = 0x12345678;
    return _TeleportHarness._(
      world: world,
      player: player,
      hashash: hashash,
      authority: authority,
    );
  }

  final EcsWorld world;
  final int player;
  final int hashash;
  final TerrainMultiBodyWorldMotionAuthority authority;

  void resolve() {
    HashashTeleportAmbushSystem(
      tickHz: 60,
      worldMotionAuthority: authority,
    ).step(world, player: player, currentTick: resolutionTick);
  }

  int get phase =>
      world.hashashTeleport.phase[world.hashashTeleport.indexOf(hashash)];
  int get rngState =>
      world.hashashTeleport.rngState[world.hashashTeleport.indexOf(hashash)];

  EnemyTerrainCheckpointSignatureRecord checkpoint(String code) => _checkpoint(
    world,
    enemy: hashash,
    tick: resolutionTick,
    teleportCode: code,
    combatCommitCode:
        world.meleeIntent.abilityId[world.meleeIntent.indexOf(hashash)] ?? '',
  );
}

TerrainGeometry _teleportBlockerGeometry(
  List<String> blockerIds, {
  required bool reverse,
}) {
  final blockers = <TerrainPolygonInput>[];
  for (final id in blockerIds) {
    final primary = id.endsWith('primary');
    final kind = id.split('-').first;
    blockers.add(_teleportBlocker(kind, id, primary ? 336 : 264));
  }
  return _compile(<TerrainPolygonInput>[
    _rectangle('teleport-floor', 0, 500, 1000, 600),
    ...blockers,
  ], reverse: reverse);
}

TerrainPolygonInput _teleportBlocker(String kind, String id, double bodyX) {
  final capsuleCenterY = _ambushBodyY() + 7;
  return switch (kind) {
    'wall' => _rectangle(
      id,
      bodyX - 2,
      _ambushBodyY() - 30,
      bodyX + 2,
      _ambushBodyY() + 40,
    ),
    'ceiling' => _rectangle(
      id,
      bodyX - 10,
      capsuleCenterY - 2,
      bodyX + 10,
      capsuleCenterY + 2,
    ),
    'slope' => _polygon(id, <(double, double)>[
      (bodyX - 18, capsuleCenterY + 18),
      (bodyX + 18, capsuleCenterY - 18),
      (bodyX + 18, capsuleCenterY + 30),
    ]),
    'concave' => _polygon(id, <(double, double)>[
      (bodyX - 18, capsuleCenterY - 18),
      (bodyX + 18, capsuleCenterY - 18),
      (bodyX + 18, capsuleCenterY + 18),
      (bodyX, capsuleCenterY + 18),
      (bodyX, capsuleCenterY),
      (bodyX - 18, capsuleCenterY),
    ]),
    _ => throw ArgumentError.value(kind, 'kind'),
  };
}

double _ambushBodyY() {
  final player = _playerArchetype();
  return 500 - player.collider.offsetY - player.collider.halfY - 36;
}

final class _FlyingHarness {
  _FlyingHarness._({
    required this.world,
    required this.player,
    required this.enemy,
    required this.authority,
    required this.movement,
    required this.locomotion,
    required this.groundTopY,
  });

  factory _FlyingHarness.create({
    required TerrainGeometry geometry,
    required double enemyX,
    required double enemyY,
    required double playerX,
    double playerY = 100,
    double groundTopY = 1000,
    UnocoDemonTuning tuning = const UnocoDemonTuning(),
  }) {
    final world = EcsWorld(seed: enemyTerrainRunSeed);
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final playerArchetype = _playerArchetype();
    final factory = EntityFactory(world);
    final player = factory.createPlayer(
      posX: 2100,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: playerArchetype.facing,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    final archetype = const EnemyCatalog().get(EnemyId.unocoDemon);
    final enemy = factory.createEnemy(
      enemyId: EnemyId.unocoDemon,
      posX: enemyX,
      posY: enemyY,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      artFacing: archetype.artFacingDir,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
      tags: archetype.tags,
      resistance: archetype.resistance,
      statusImmunity: archetype.statusImmunity,
    );
    final authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    final playerIndex = world.transform.indexOf(player);
    world.transform.posX[playerIndex] = playerX;
    world.transform.posY[playerIndex] = playerY;
    world.body.enabled[world.body.indexOf(player)] = false;
    return _FlyingHarness._(
      world: world,
      player: player,
      enemy: enemy,
      authority: authority,
      movement: movement,
      locomotion: FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(tuning, tickHz: 60),
        worldMotionAuthority: authority,
      ),
      groundTopY: groundTopY,
    );
  }

  final EcsWorld world;
  final int player;
  final int enemy;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final MovementTuningDerived movement;
  final FlyingEnemyLocomotionSystem locomotion;
  final double groundTopY;
  int tick = 0;

  void configureHover({required double height, required double desiredRange}) {
    final index = world.flyingEnemySteering.indexOf(enemy);
    world.flyingEnemySteering.initialized[index] = true;
    world.flyingEnemySteering.desiredRange[index] = desiredRange;
    world.flyingEnemySteering.desiredRangeHoldLeftS[index] = 1000;
    world.flyingEnemySteering.flightTargetAboveGround[index] = height;
    world.flyingEnemySteering.flightTargetHoldLeftS[index] = 1000;
  }

  void stepLocomotion() {
    tick += 1;
    authority.prepareTick(world, player: player, currentTick: tick);
    locomotion.step(
      world,
      player: player,
      groundTopY: groundTopY,
      dtSeconds: movement.dtSeconds,
      currentTick: tick,
    );
    _integrate();
  }

  void stepMotion({required double velocityX, required double velocityY}) {
    tick += 1;
    authority.prepareTick(world, player: player, currentTick: tick);
    final index = world.transform.indexOf(enemy);
    world.transform.velX[index] = velocityX;
    world.transform.velY[index] = velocityY;
    _integrate();
  }

  void _integrate() {
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: tick,
    );
  }

  int get _steeringIndex => world.flyingEnemySteering.indexOf(enemy);
  int get _contactIndex => world.terrainContact.indexOf(enemy);
  bool get hasLocalTerrainReference =>
      world.flyingEnemySteering.hasLocalTerrainReference[_steeringIndex];
  double get effectiveFlightReferenceY =>
      world.flyingEnemySteering.effectiveFlightReferenceY[_steeringIndex];
  int get clearanceCandidateId =>
      world.flyingEnemySteering.clearanceCandidateId[_steeringIndex];
  int get blockingContactCount =>
      world.terrainContact.blockingContactCount[_contactIndex];
  EnemyTerrainCheckpointSignatureRecord checkpoint() =>
      _checkpoint(world, enemy: enemy, tick: tick);
}

TerrainSpawnPlacementResult _resolveDerfPlacement(
  TerrainGeometry geometry, {
  required double x,
  required double supportY,
}) {
  const catalog = EnemyCatalog();
  final collider = catalog.get(EnemyId.derf).collider;
  return TerrainMultiBodyWorldMotionAuthority(
    geometry: geometry,
    playerProfile: _playerArchetype().terrainTraversalProfile,
  ).resolveSpawnPlacement(
    TerrainSpawnPlacementRequest(
      profile: TerrainEnemySpawnPlacementProfile.fromCatalog(
        catalog: catalog,
        enemyId: EnemyId.derf,
        facing: Facing.left,
      ),
      desiredBodyCenter: TerrainPoint.fromWorld(
        x,
        supportY - collider.offsetY - collider.halfY,
      ),
      supportSelection: TerrainSpawnSupportSelection.obstacleTop,
      requestedSupportYTicks: _ticks(supportY),
      allowSameSupportClamp: true,
    ),
  );
}

({
  String abilityId,
  int targetXTicks,
  int targetYTicks,
  int executeTick,
  EnemyTerrainCheckpointSignatureRecord checkpoint,
})
_castDerf(TerrainSpawnPlacementResult placement) {
  _ensure(placement.accepted, 'Derf cast requires accepted placement');
  final world = EcsWorld(seed: enemyTerrainRunSeed);
  final factory = EntityFactory(world);
  const catalog = EnemyCatalog();
  final playerArchetype = _playerArchetype();
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
  final archetype = catalog.get(EnemyId.derf);
  final derf = factory.createEnemy(
    enemyId: EnemyId.derf,
    posX: placement.bodyCenter!.xTicks / terrainPhysicsTicksPerWorldUnit,
    posY: placement.bodyCenter!.yTicks / terrainPhysicsTicksPerWorldUnit,
    velX: 0,
    velY: 0,
    facing: Facing.right,
    artFacing: archetype.artFacingDir,
    body: archetype.body,
    collider: archetype.collider,
    health: archetype.health,
    mana: archetype.mana,
    stamina: archetype.stamina,
    tags: archetype.tags,
    resistance: archetype.resistance,
    statusImmunity: archetype.statusImmunity,
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
  final intentIndex = world.targetPointIntent.indexOf(derf);
  final abilityId = world.targetPointIntent.abilityId[intentIndex];
  return (
    abilityId: abilityId,
    targetXTicks: _ticks(world.targetPointIntent.targetX[intentIndex]),
    targetYTicks: _ticks(world.targetPointIntent.targetY[intentIndex]),
    executeTick: world.targetPointIntent.tick[intentIndex],
    checkpoint: _checkpoint(
      world,
      enemy: derf,
      tick: 10,
      combatCommitCode: abilityId,
    ),
  );
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

TerrainPolygonInput _playerSpawnPolygon() =>
    _rectangle('player-spawn', 2000, 1000, 2200, 1100, chunkIndex: 99);

final class _MixedEnemyHarness {
  _MixedEnemyHarness._({
    required this.world,
    required this.player,
    required this.groundEnemies,
    required this.flyingEnemies,
    required this.derfs,
    required this.authority,
    required this.movement,
    required this.groundLocomotion,
    required this.flyingLocomotion,
  });

  factory _MixedEnemyHarness.create({required TerrainGeometry geometry}) {
    final world = EcsWorld(seed: enemyTerrainRunSeed);
    final factory = EntityFactory(world);
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final playerArchetype = _playerArchetype();
    final player = factory.createPlayer(
      posX: 2100,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: playerArchetype.facing,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    const catalog = EnemyCatalog();
    final groundEnemies = <int>[];
    final flyingEnemies = <int>[];
    final derfs = <int>[];

    int spawn(EnemyId id, double x, double y) {
      final archetype = catalog.get(id);
      return factory.createEnemy(
        enemyId: id,
        posX: x,
        posY: y,
        velX: 0,
        velY: 0,
        facing: Facing.right,
        artFacing: archetype.artFacingDir,
        body: archetype.body,
        collider: archetype.collider,
        health: archetype.health,
        mana: archetype.mana,
        stamina: archetype.stamina,
        tags: archetype.tags,
        resistance: archetype.resistance,
        statusImmunity: archetype.statusImmunity,
      );
    }

    for (var index = 0; index < 8; index += 1) {
      final x = 80.0 + index * 45;
      final supportY = 900 - x / 8;
      final archetype = catalog.get(EnemyId.grojib);
      groundEnemies.add(
        spawn(
          EnemyId.grojib,
          x,
          supportY - archetype.collider.offsetY - archetype.collider.halfY - 8,
        ),
      );
    }
    for (var index = 0; index < 8; index += 1) {
      final x = 480.0 + index * 45;
      final supportY = 900 - x / 8;
      final archetype = catalog.get(EnemyId.hashash);
      groundEnemies.add(
        spawn(
          EnemyId.hashash,
          x,
          supportY - archetype.collider.offsetY - archetype.collider.halfY - 8,
        ),
      );
    }
    for (var index = 0; index < 4; index += 1) {
      flyingEnemies.add(spawn(EnemyId.unocoDemon, 300 + index * 100, 350));
      derfs.add(spawn(EnemyId.derf, 900 + index * 80, 500));
    }
    final authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    world.body.enabled[world.body.indexOf(player)] = false;
    return _MixedEnemyHarness._(
      world: world,
      player: player,
      groundEnemies: groundEnemies,
      flyingEnemies: flyingEnemies,
      derfs: derfs,
      authority: authority,
      movement: movement,
      groundLocomotion: GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          const GroundEnemyTuning(),
          tickHz: 60,
        ),
      ),
      flyingLocomotion: FlyingEnemyLocomotionSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
        worldMotionAuthority: authority,
      ),
    );
  }

  final EcsWorld world;
  final int player;
  final List<int> groundEnemies;
  final List<int> flyingEnemies;
  final List<int> derfs;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final MovementTuningDerived movement;
  final GroundEnemyLocomotionSystem groundLocomotion;
  final FlyingEnemyLocomotionSystem flyingLocomotion;
  final GravitySystem _gravity = GravitySystem();
  int tick = 0;

  int get groundEnemyCount => groundEnemies.length;
  int get flyingEnemyCount => flyingEnemies.length;
  int get derfCount => derfs.length;
  int get lastIntegratedBodyCount => authority.lastIntegratedBodyCount;

  void run(int count) {
    for (var iteration = 0; iteration < count; iteration += 1) {
      tick += 1;
      authority.prepareTick(world, player: player, currentTick: tick);
      for (final enemy in groundEnemies) {
        final navIndex = world.navIntent.indexOf(enemy);
        world.navIntent.desiredX[navIndex] = 1400;
        world.navIntent.jumpNow[navIndex] = false;
        world.navIntent.hasPlan[navIndex] = false;
        world.navIntent.commitMoveDirX[navIndex] = 0;
        world.navIntent.hasSafeSurface[navIndex] = false;
        final engagementIndex = world.engagementIntent.indexOf(enemy);
        world.engagementIntent.desiredTargetX[engagementIndex] = 1400;
        world.engagementIntent.speedScale[engagementIndex] = 1;
        world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0;
        world.engagementIntent.stateSpeedMul[engagementIndex] = 1;
      }
      groundLocomotion.step(
        world,
        player: player,
        dtSeconds: movement.dtSeconds,
        currentTick: tick,
      );
      flyingLocomotion.step(
        world,
        player: player,
        groundTopY: 900,
        dtSeconds: movement.dtSeconds,
        currentTick: tick,
      );
      _gravity.step(world, movement, physics: const PhysicsTuning());
      authority.step(
        world,
        player: player,
        movement: movement,
        fixedPointPilotEnabled: false,
        fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
        currentTick: tick,
      );
    }
  }

  List<EnemyTerrainCheckpointSignatureRecord> checkpoints() =>
      <EnemyTerrainCheckpointSignatureRecord>[
        for (final enemy in <int>[...groundEnemies, ...flyingEnemies, ...derfs])
          _checkpoint(world, enemy: enemy, tick: tick),
      ];
}

final class _MotionHarness {
  _MotionHarness._({
    required this.world,
    required this.player,
    required this.enemies,
    required this.movement,
    required this.authority,
    required this.locomotion,
  });

  factory _MotionHarness.one({
    required TerrainGeometry geometry,
    required EnemyId enemyId,
    required double enemyX,
    required double enemySupportY,
    required double speedX,
  }) {
    final world = EcsWorld(seed: enemyTerrainRunSeed);
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final playerArchetype = PlayerCatalogDerived.from(
      eloiseCharacter.catalog,
      movement: movement,
      resources: ResourceTuningDerived.from(eloiseCharacter.tuning.resource),
    ).archetype;
    final factory = EntityFactory(world);
    final player = factory.createPlayer(
      posX: 0,
      posY: -500,
      velX: 0,
      velY: 0,
      facing: playerArchetype.facing,
      grounded: false,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );
    final enemyArchetype = const EnemyCatalog().get(enemyId);
    final enemy = factory.createEnemy(
      enemyId: enemyId,
      posX: enemyX,
      posY:
          enemySupportY -
          enemyArchetype.collider.offsetY -
          enemyArchetype.collider.halfY -
          12,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      artFacing: enemyArchetype.artFacingDir,
      body: enemyArchetype.body,
      collider: enemyArchetype.collider,
      health: enemyArchetype.health,
      mana: enemyArchetype.mana,
      stamina: enemyArchetype.stamina,
      tags: enemyArchetype.tags,
      resistance: enemyArchetype.resistance,
      statusImmunity: enemyArchetype.statusImmunity,
    );
    final authority = TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: playerArchetype.terrainTraversalProfile,
    );
    authority.initializePlayer(
      world,
      player: player,
      archetype: playerArchetype,
    );
    return _MotionHarness._(
      world: world,
      player: player,
      enemies: <int>[enemy],
      movement: movement,
      authority: authority,
      locomotion: GroundEnemyLocomotionSystem(
        groundEnemyTuning: GroundEnemyTuningDerived.from(
          GroundEnemyTuning(
            locomotion: GroundEnemyLocomotionTuning(
              speedX: speedX,
              accelX: 100000,
              decelX: 100000,
              stopDistanceX: 0.1,
              jumpSpeed: 500,
            ),
          ),
          tickHz: 60,
        ),
      ),
    );
  }

  final EcsWorld world;
  final int player;
  final List<int> enemies;
  final MovementTuningDerived movement;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final GroundEnemyLocomotionSystem locomotion;
  final GravitySystem _gravity = GravitySystem();
  int tick = 0;

  bool grounded(int enemy) {
    final index = world.terrainContact.tryIndexOf(enemy);
    return index != null && world.terrainContact.grounded[index];
  }

  double velocityX(int enemy) =>
      world.transform.velX[world.transform.indexOf(enemy)];

  double bodyX(int enemy) =>
      world.transform.posX[world.transform.indexOf(enemy)];

  void settle() {
    final enemy = enemies.single;
    for (var count = 0; count < 120 && !grounded(enemy); count += 1) {
      _step(<int, double>{enemy: _bodyX(enemy)});
    }
    _ensure(grounded(enemy), 'enemy failed to settle on terrain');
    for (var count = 0; count < 60; count += 1) {
      final ti = world.transform.indexOf(enemy);
      if ((world.transform.velX[ti].abs() + world.transform.velY[ti].abs()) <=
          1e-6) {
        break;
      }
      _step(<int, double>{enemy: _bodyX(enemy)});
    }
  }

  void run(
    int count, {
    required Map<int, double> targets,
    void Function()? onTick,
  }) {
    for (var index = 0; index < count; index += 1) {
      _step(targets);
      onTick?.call();
    }
  }

  void step({
    required double targetX,
    bool jumpNow = false,
    int commitMoveDirX = 0,
    double speedScale = 1,
    double stateSpeedMul = 1,
  }) {
    _step(
      <int, double>{enemies.single: targetX},
      jumpNow: jumpNow,
      commitMoveDirX: commitMoveDirX,
      speedScale: speedScale,
      stateSpeedMul: stateSpeedMul,
    );
  }

  EnemyTerrainCheckpointSignatureRecord checkpoint(int enemy) =>
      _checkpoint(world, enemy: enemy, tick: tick);

  double _bodyX(int enemy) =>
      world.transform.posX[world.transform.indexOf(enemy)];

  void _step(
    Map<int, double> targets, {
    bool jumpNow = false,
    int commitMoveDirX = 0,
    double speedScale = 1,
    double stateSpeedMul = 1,
  }) {
    tick += 1;
    authority.prepareTick(world, player: player, currentTick: tick);
    for (final enemy in enemies) {
      final target = targets[enemy] ?? _bodyX(enemy);
      final navIndex = world.navIntent.indexOf(enemy);
      world.navIntent.desiredX[navIndex] = target;
      world.navIntent.jumpNow[navIndex] = jumpNow;
      world.navIntent.hasPlan[navIndex] = false;
      world.navIntent.commitMoveDirX[navIndex] = commitMoveDirX;
      world.navIntent.hasSafeSurface[navIndex] = false;
      final engagementIndex = world.engagementIntent.indexOf(enemy);
      world.engagementIntent.desiredTargetX[engagementIndex] = target;
      world.engagementIntent.speedScale[engagementIndex] = speedScale;
      world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0;
      world.engagementIntent.stateSpeedMul[engagementIndex] = stateSpeedMul;
    }
    locomotion.step(
      world,
      player: player,
      dtSeconds: movement.dtSeconds,
      currentTick: tick,
    );
    _gravity.step(world, movement, physics: const PhysicsTuning());
    authority.step(
      world,
      player: player,
      movement: movement,
      fixedPointPilotEnabled: false,
      fixedPointSubpixelScale: terrainPhysicsTicksPerWorldUnit,
      currentTick: tick,
    );
  }
}

EnemyTerrainCheckpointSignatureRecord _checkpoint(
  EcsWorld world, {
  required int enemy,
  required int tick,
  String teleportCode = '',
  String combatCommitCode = '',
  String lifecycleCode = 'alive',
}) {
  final transformIndex = world.transform.indexOf(enemy);
  final enemyIndex = world.enemy.indexOf(enemy);
  final contactIndex = world.terrainContact.tryIndexOf(enemy);
  final navIndex = world.surfaceNav.tryIndexOf(enemy);
  final contactCount = contactIndex == null
      ? 0
      : world.terrainContact.blockingContactCount[contactIndex];
  final contactIds = contactIndex == null
      ? const <TerrainEdgeId>[]
      : world.terrainContact.blockingContactEdgeIds[contactIndex]
            .take(contactCount)
            .whereType<TerrainEdgeId>()
            .toList(growable: false);
  return EnemyTerrainCheckpointSignatureRecord(
    tick: tick,
    entityId: enemy,
    enemyId: world.enemy.enemyId[enemyIndex],
    bodyXTicks: physicsCoordinateToTicks(
      world.transform.posX[transformIndex],
      name: 'enemyBodyX',
    ),
    bodyYTicks: physicsCoordinateToTicks(
      world.transform.posY[transformIndex],
      name: 'enemyBodyY',
    ),
    velocityXTicks: physicsCoordinateToTicks(
      world.transform.velX[transformIndex],
      name: 'enemyVelocityX',
    ),
    velocityYTicks: physicsCoordinateToTicks(
      world.transform.velY[transformIndex],
      name: 'enemyVelocityY',
    ),
    bundleVersion: contactIndex == null
        ? -1
        : world.terrainContact.supportGeometryVersion[contactIndex],
    grounded:
        contactIndex != null && world.terrainContact.grounded[contactIndex],
    supportEdgeId: contactIndex == null
        ? null
        : world.terrainContact.supportEdgeId[contactIndex],
    navGraphVersion: navIndex == null
        ? -1
        : world.surfaceNav.graphVersion[navIndex],
    currentSurfaceId: navIndex == null
        ? surfaceIdUnknown
        : world.surfaceNav.currentSurfaceId[navIndex],
    lastGroundSurfaceId: navIndex == null
        ? surfaceIdUnknown
        : world.surfaceNav.lastGroundSurfaceId[navIndex],
    targetSurfaceId: navIndex == null
        ? surfaceIdUnknown
        : world.surfaceNav.targetSurfaceId[navIndex],
    activeEdgeIndex: navIndex == null
        ? -1
        : world.surfaceNav.activeEdgeIndex[navIndex],
    pathCursor: navIndex == null ? 0 : world.surfaceNav.pathCursor[navIndex],
    pathEdges: navIndex == null
        ? const <int>[]
        : List<int>.of(world.surfaceNav.pathEdges[navIndex]),
    hitLeft: contactIndex != null && world.terrainContact.hitLeft[contactIndex],
    hitRight:
        contactIndex != null && world.terrainContact.hitRight[contactIndex],
    hitCeiling:
        contactIndex != null && world.terrainContact.hitCeiling[contactIndex],
    contactEdgeIds: contactIds,
    teleportCode: teleportCode,
    combatCommitCode: combatCommitCode,
    lifecycleCode: lifecycleCode,
  );
}

EnemyTerrainScenarioSignatureInput _scenario({
  required String id,
  required String fixture,
  required List<String> profiles,
  required List<EnemyTerrainScheduleSignatureRecord> schedule,
  List<EnemyTerrainCheckpointSignatureRecord> checkpoints =
      const <EnemyTerrainCheckpointSignatureRecord>[],
  required List<EnemyTerrainOutcomeSignatureRecord> outcomes,
  required String legacy,
}) => EnemyTerrainScenarioSignatureInput(
  scenarioId: id,
  fixtureId: fixture,
  seed: enemyTerrainRunSeed,
  actorProfiles: profiles,
  schedule: schedule,
  checkpoints: checkpoints,
  outcomes: outcomes,
  legacyDisposition: legacy,
);

TerrainRuntimeBundle _bundle(
  List<TerrainPolygonInput> inputs, {
  required bool reverse,
  int version = 23,
}) => TerrainRuntimeBundle.build(
  geometry: _compile(inputs, reverse: reverse, version: version),
  groundEnemyProfiles: buildDefaultGroundEnemyTerrainGraphProfiles(),
);

TerrainGeometry _compile(
  List<TerrainPolygonInput> inputs, {
  required bool reverse,
  int version = 23,
}) => const TerrainCompiler().compile(
  reverse ? inputs.reversed : inputs,
  geometryVersion: version,
);

TerrainPolygonInput _ground(
  String shapeId,
  List<(double, double)> top, {
  int chunkIndex = 0,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) {
  _ensure(top.length >= 2, '$shapeId needs at least two top vertices');
  return _polygon(
    shapeId,
    <(double, double)>[
      ...top,
      (top.last.$1, top.last.$2 + 300),
      (top.first.$1, top.first.$2 + 300),
    ],
    chunkIndex: chunkIndex,
    collisionMode: collisionMode,
  );
}

TerrainPolygonInput _polygon(
  String shapeId,
  List<(double, double)> vertices, {
  int chunkIndex = 0,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => TerrainPolygonInput.fromWorld(
  sourcePath: 'test/enemy-terrain-run/$shapeId',
  identity: TerrainSourceIdentity(
    chunkIndex: chunkIndex,
    chunkKey: 'sg-e',
    shapeId: shapeId,
  ),
  collisionMode: collisionMode,
  vertices: vertices,
);

TerrainPolygonInput _rectangle(
  String shapeId,
  double left,
  double top,
  double right,
  double bottom, {
  int chunkIndex = 0,
  TerrainCollisionMode collisionMode = TerrainCollisionMode.solid,
}) => _polygon(
  shapeId,
  <(double, double)>[
    (left, top),
    (right, top),
    (right, bottom),
    (left, bottom),
  ],
  chunkIndex: chunkIndex,
  collisionMode: collisionMode,
);

TerrainGeometry _stepGeometry(int heightPixels, {required bool reverse}) =>
    _compile(<TerrainPolygonInput>[
      _rectangle('step-$heightPixels-left', 0, 500, 300, 800),
      _rectangle(
        'step-$heightPixels-right',
        300,
        500.0 - heightPixels,
        700,
        800,
        chunkIndex: 1,
      ),
    ], reverse: reverse);

TerrainGeometry _dropGeometry(int heightPixels, {required bool reverse}) =>
    _compile(<TerrainPolygonInput>[
      _rectangle('drop-$heightPixels-left', 0, 500, 300, 800),
      _rectangle(
        'drop-$heightPixels-right',
        300,
        500.0 + heightPixels,
        700,
        800,
        chunkIndex: 1,
      ),
    ], reverse: reverse);

int _ticks(double value) => physicsCoordinateToTicks(value, name: 'fixture');

void _ensure(bool condition, String message) {
  if (!condition) throw StateError(message);
}
