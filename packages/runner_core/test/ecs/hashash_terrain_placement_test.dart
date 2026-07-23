import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_numeric.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/enemies/hashash_teleport_state_store.dart';
import 'package:runner_core/ecs/systems/hashash_teleport_ambush_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/navigation/types/surface_id.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_archetype.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:test/test.dart';

void main() {
  group('Hashash terrain-authoritative teleport', () {
    test('commits the primary right-side point as unsupported airborne', () {
      final harness = _TeleportHarness.create(
        geometry: _compile(<TerrainPolygonInput>[
          _rectangle('narrow-floor', 270, 500, 330, 600),
        ]),
      );

      harness.resolveTeleport();

      expect(harness.phase, HashashTeleportPhase.ambush);
      expect(harness.hashashX, closeTo(harness.playerX + 36, 1 / 1024));
      expect(harness.hashashY, closeTo(harness.playerY - 36, 1 / 1024));
      expect(harness.facing, Facing.left);
      expect(
        harness.world.meleeIntent.abilityId[harness.meleeIndex],
        'hashash.ambush',
      );
      expect(harness.contactGrounded, isFalse);
      expect(harness.supportEdgeId, isNull);
      expect(harness.hasLastValidBody, isTrue);
      expect(harness.hasLastCapsuleState, isTrue);
      expect(harness.currentSurfaceId, surfaceIdUnknown);
      expect(harness.pathEdges, isEmpty);
    });

    test(
      'tries the mirrored left-side point only after primary is blocked',
      () {
        final first = _TeleportHarness.create(
          geometry: _geometryWithBlockers(<TerrainPolygonInput>[
            _wallBlocker('primary', 336),
          ]),
        )..resolveTeleport();
        final reordered = _TeleportHarness.create(
          geometry: _geometryWithBlockers(<TerrainPolygonInput>[
            _wallBlocker('primary', 336),
          ], reverseInput: true),
        )..resolveTeleport();

        for (final harness in <_TeleportHarness>[first, reordered]) {
          expect(harness.phase, HashashTeleportPhase.ambush);
          expect(harness.hashashX, closeTo(harness.playerX - 36, 1 / 1024));
          expect(harness.hashashY, closeTo(harness.playerY - 36, 1 / 1024));
          expect(harness.facing, Facing.right);
          expect(
            harness.world.meleeIntent.abilityId[harness.meleeIndex],
            'hashash.ambush',
          );
        }
        expect(first.hashashX, reordered.hashashX);
        expect(first.hashashY, reordered.hashashY);
      },
    );

    test('wall, ceiling, slope, and concave blockage cancel safely', () {
      for (final kind in _BlockerKind.values) {
        final harness = _TeleportHarness.create(
          geometry: _geometryWithBlockers(<TerrainPolygonInput>[
            _blocker(kind, '${kind.name}-right', 336),
            _blocker(kind, '${kind.name}-left', 264),
          ]),
        );
        final initialRng = harness.rngState;
        final successfulCooldown = harness.expectedCooldownUntilTick;

        harness.resolveTeleport();

        expect(harness.phase, HashashTeleportPhase.idle, reason: kind.name);
        expect(harness.phaseEndTick, -1, reason: kind.name);
        expect(harness.hashashX, closeTo(100, 1 / 1024), reason: kind.name);
        expect(
          harness.hashashY,
          closeTo(harness.safeHashashBodyY, 1 / 1024),
          reason: kind.name,
        );
        expect(
          harness.world.meleeIntent.abilityId[harness.meleeIndex],
          isNull,
          reason: kind.name,
        );
        expect(
          harness.cooldownUntilTick,
          successfulCooldown,
          reason: kind.name,
        );
        expect(harness.rngState, initialRng, reason: kind.name);
        expect(harness.hasLastValidBody, isTrue, reason: kind.name);
        expect(harness.hasLastCapsuleState, isTrue, reason: kind.name);
        expect(harness.currentSurfaceId, surfaceIdUnknown, reason: kind.name);
        expect(harness.pathEdges, isEmpty, reason: kind.name);
      }
    });
  });

  group('deferred grounded Hashash placement', () {
    test('accepts an exact-X fully supported slope placement', () {
      final authority = _authority(
        _compile(<TerrainPolygonInput>[
          TerrainPolygonInput.fromWorld(
            sourcePath: 'test/slope',
            identity: TerrainSourceIdentity(
              chunkIndex: 0,
              chunkKey: 'test',
              shapeId: 'slope',
            ),
            vertices: const <(double, double)>[
              (0, 500),
              (1000, 300),
              (1000, 700),
              (0, 700),
            ],
          ),
        ]),
      );

      final placement = authority.resolveGroundedEnemySpawn(
        enemyId: EnemyId.hashash,
        desiredBodyX: 500,
        requestedSupportY: 400,
      );

      expect(placement, isNotNull);
      expect(placement!.bodyX, closeTo(500, 1 / 1024));
      expect(placement.bodyY, lessThan(400));
    });

    test(
      'rejects invalid highest support instead of using a lower surface',
      () {
        final authority = _authority(
          _compile(<TerrainPolygonInput>[
            _rectangle('lower-floor', 0, 600, 1000, 700),
            _rectangle('narrow-highest', 490, 400, 510, 450),
          ]),
        );

        final placement = authority.resolveGroundedEnemySpawn(
          enemyId: EnemyId.hashash,
          desiredBodyX: 500,
          requestedSupportY: 400,
        );

        expect(placement, isNull);
      },
    );
  });
}

enum _BlockerKind { wall, ceiling, slope, concave }

final class _TeleportHarness {
  _TeleportHarness._({
    required this.world,
    required this.player,
    required this.hashash,
    required this.authority,
    required this.safeHashashBodyY,
  });

  static const int resolutionTick = 25;

  factory _TeleportHarness.create({required TerrainGeometry geometry}) {
    final world = EcsWorld(seed: 41);
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
    final hashashArchetype = const EnemyCatalog().get(EnemyId.hashash);
    final safeBodyY =
        500 -
        hashashArchetype.collider.offsetY -
        hashashArchetype.collider.halfY;
    final hashash = factory.createEnemy(
      enemyId: EnemyId.hashash,
      posX: 100,
      posY: safeBodyY,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      artFacing: hashashArchetype.artFacingDir,
      body: hashashArchetype.body,
      collider: hashashArchetype.collider,
      health: hashashArchetype.health,
      mana: hashashArchetype.mana,
      stamina: hashashArchetype.stamina,
      tags: hashashArchetype.tags,
      resistance: hashashArchetype.resistance,
      statusImmunity: hashashArchetype.statusImmunity,
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

    final profile = const EnemyCatalog().terrainContactProfile(EnemyId.hashash);
    world.terrainContact.setLastValidBodyPosition(
      hashash,
      xTicks: physicsCoordinateToTicks(100, name: 'safeX'),
      yTicks: physicsCoordinateToTicks(safeBodyY, name: 'safeY'),
    );
    world.terrainContact.setLastCapsuleState(
      hashash,
      centerXTicks: physicsCoordinateToTicks(
        100 + profile.capsule.offsetX,
        name: 'safeCapsuleX',
      ),
      centerYTicks: physicsCoordinateToTicks(
        safeBodyY + profile.capsule.offsetY,
        name: 'safeCapsuleY',
      ),
      facingSign: 1,
    );
    final navIndex = world.surfaceNav.indexOf(hashash);
    world.surfaceNav.graphVersion[navIndex] = geometry.version;
    world.surfaceNav.currentSurfaceId[navIndex] = 17;
    world.surfaceNav.lastGroundSurfaceId[navIndex] = 17;
    world.surfaceNav.targetSurfaceId[navIndex] = 18;
    world.surfaceNav.activeEdgeIndex[navIndex] = 0;
    world.surfaceNav.pathCursor[navIndex] = 1;
    world.surfaceNav.pathEdges[navIndex].addAll(<int>[17, 18]);

    final teleportIndex = world.hashashTeleport.indexOf(hashash);
    world.hashashTeleport.phase[teleportIndex] = HashashTeleportPhase.evadeOut;
    world.hashashTeleport.phaseEndTick[teleportIndex] = resolutionTick;
    world.hashashTeleport.rngState[teleportIndex] = 0x12345678;
    return _TeleportHarness._(
      world: world,
      player: player,
      hashash: hashash,
      authority: authority,
      safeHashashBodyY: safeBodyY,
    );
  }

  final EcsWorld world;
  final int player;
  final int hashash;
  final TerrainMultiBodyWorldMotionAuthority authority;
  final double safeHashashBodyY;

  void resolveTeleport() {
    HashashTeleportAmbushSystem(
      tickHz: 60,
      worldMotionAuthority: authority,
    ).step(world, player: player, currentTick: resolutionTick);
  }

  int get transformIndex => world.transform.indexOf(hashash);
  int get teleportIndex => world.hashashTeleport.indexOf(hashash);
  int get meleeIndex => world.meleeIntent.indexOf(hashash);
  int get contactIndex => world.terrainContact.indexOf(hashash);
  int get navIndex => world.surfaceNav.indexOf(hashash);
  double get playerX => world.transform.posX[world.transform.indexOf(player)];
  double get playerY => world.transform.posY[world.transform.indexOf(player)];
  double get hashashX => world.transform.posX[transformIndex];
  double get hashashY => world.transform.posY[transformIndex];
  Facing get facing => world.enemy.facing[world.enemy.indexOf(hashash)];
  int get phase => world.hashashTeleport.phase[teleportIndex];
  int get phaseEndTick => world.hashashTeleport.phaseEndTick[teleportIndex];
  int get cooldownUntilTick =>
      world.hashashTeleport.cooldownUntilTick[teleportIndex];
  int get rngState => world.hashashTeleport.rngState[teleportIndex];
  bool get contactGrounded => world.terrainContact.grounded[contactIndex];
  Object? get supportEdgeId => world.terrainContact.supportEdgeId[contactIndex];
  bool get hasLastValidBody =>
      world.terrainContact.hasLastValidBodyPosition[contactIndex];
  bool get hasLastCapsuleState =>
      world.terrainContact.hasLastCapsuleState[contactIndex];
  int get currentSurfaceId => world.surfaceNav.currentSurfaceId[navIndex];
  List<int> get pathEdges => world.surfaceNav.pathEdges[navIndex];

  int get expectedCooldownUntilTick {
    final ability = AbilityCatalog.shared.resolve('hashash.ambush')!;
    return resolutionTick +
        ability.windupTicks +
        ability.activeTicks +
        ability.recoveryTicks +
        ability.cooldownTicks;
  }
}

TerrainMultiBodyWorldMotionAuthority _authority(TerrainGeometry geometry) =>
    TerrainMultiBodyWorldMotionAuthority(
      geometry: geometry,
      playerProfile: _playerArchetype().terrainTraversalProfile,
    );

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

TerrainGeometry _geometryWithBlockers(
  List<TerrainPolygonInput> blockers, {
  bool reverseInput = false,
}) {
  final inputs = <TerrainPolygonInput>[
    _rectangle('floor', 0, 500, 1000, 600),
    ...blockers,
  ];
  return _compile(reverseInput ? inputs.reversed.toList() : inputs);
}

TerrainPolygonInput _blocker(_BlockerKind kind, String id, double bodyX) {
  final capsuleCenterY = _ambushBodyY() + 7;
  return switch (kind) {
    _BlockerKind.wall => _wallBlocker(id, bodyX),
    _BlockerKind.ceiling => _rectangle(
      id,
      bodyX - 10,
      capsuleCenterY - 2,
      bodyX + 10,
      capsuleCenterY + 2,
    ),
    _BlockerKind.slope => _polygon(id, <(double, double)>[
      (bodyX - 18, capsuleCenterY + 18),
      (bodyX + 18, capsuleCenterY - 18),
      (bodyX + 18, capsuleCenterY + 30),
    ]),
    _BlockerKind.concave => _polygon(id, <(double, double)>[
      (bodyX - 18, capsuleCenterY - 18),
      (bodyX + 18, capsuleCenterY - 18),
      (bodyX + 18, capsuleCenterY + 18),
      (bodyX, capsuleCenterY + 18),
      (bodyX, capsuleCenterY),
      (bodyX - 18, capsuleCenterY),
    ]),
  };
}

TerrainPolygonInput _wallBlocker(String id, double bodyX) => _rectangle(
  id,
  bodyX - 2,
  _ambushBodyY() - 30,
  bodyX + 2,
  _ambushBodyY() + 40,
);

double _ambushBodyY() {
  final player = _playerArchetype();
  final playerBodyY = 500 - player.collider.offsetY - player.collider.halfY;
  return playerBodyY - 36;
}

TerrainPolygonInput _rectangle(
  String id,
  double left,
  double top,
  double right,
  double bottom,
) => _polygon(id, <(double, double)>[
  (left, top),
  (right, top),
  (right, bottom),
  (left, bottom),
]);

TerrainPolygonInput _polygon(String id, List<(double, double)> vertices) =>
    TerrainPolygonInput.fromWorld(
      sourcePath: 'test/$id',
      identity: TerrainSourceIdentity(
        chunkIndex: 0,
        chunkKey: 'test',
        shapeId: id,
      ),
      vertices: vertices,
    );

TerrainGeometry _compile(List<TerrainPolygonInput> inputs) =>
    const TerrainCompiler().compile(inputs, geometryVersion: 17);
