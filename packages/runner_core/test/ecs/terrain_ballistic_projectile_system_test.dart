import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/projectile_store.dart';
import 'package:runner_core/ecs/systems/terrain_ballistic_projectile_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/players/characters/eloise.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:test/test.dart';

void main() {
  group('terrain ballistic projectile system', () {
    final movement = MovementTuningDerived.from(
      eloiseCharacter.tuning.movement,
      tickHz: 60,
    );
    final oneWayGeometry = const TerrainCompiler().compile(
      <TerrainPolygonInput>[
        TerrainPolygonInput.fromWorld(
          sourcePath: 'test/one-way-projectile',
          identity: TerrainSourceIdentity(
            chunkIndex: 0,
            chunkKey: 'test',
            shapeId: 'platform',
          ),
          vertices: <(double, double)>[
            (100, 100),
            (200, 100),
            (200, 110),
            (100, 110),
          ],
          collisionMode: TerrainCollisionMode.oneWay,
        ),
      ],
      geometryVersion: 1,
    );
    final solidGeometry = const TerrainCompiler().compile(<TerrainPolygonInput>[
      TerrainPolygonInput.fromWorld(
        sourcePath: 'test/solid-projectile',
        identity: TerrainSourceIdentity(
          chunkIndex: 0,
          chunkKey: 'test',
          shapeId: 'solid',
        ),
        vertices: <(double, double)>[
          (100, 100),
          (200, 100),
          (200, 200),
          (100, 200),
        ],
      ),
    ], geometryVersion: 1);

    test('lands from above on the finite one-way face', () {
      final world = EcsWorld();
      final projectile = _spawnBallistic(world, x: 150, y: 50, velocityY: 6000);
      final system = TerrainBallisticProjectileSystem(
        edgeIndex: TerrainEdgeIndex(edges: oneWayGeometry.edges),
      );

      system.step(world, movement);

      final transformIndex = world.transform.indexOf(projectile);
      final collisionIndex = world.collision.indexOf(projectile);
      expect(world.transform.posY[transformIndex], closeTo(95, 1 / 1024));
      expect(world.collision.grounded[collisionIndex], isTrue);
      expect(system.lastIntegratedProjectileCount, 1);
    });

    test('passes upward through a one-way platform from below', () {
      final world = EcsWorld();
      final projectile = _spawnBallistic(
        world,
        x: 150,
        y: 150,
        velocityY: -6000,
      );
      final system = TerrainBallisticProjectileSystem(
        edgeIndex: TerrainEdgeIndex(edges: oneWayGeometry.edges),
      );

      system.step(world, movement);

      final transformIndex = world.transform.indexOf(projectile);
      final collisionIndex = world.collision.indexOf(projectile);
      expect(world.transform.posY[transformIndex], closeTo(50, 1 / 1024));
      expect(world.collision.grounded[collisionIndex], isFalse);
      expect(world.collision.hitCeiling[collisionIndex], isFalse);
      expect(world.collision.hitLeft[collisionIndex], isFalse);
      expect(world.collision.hitRight[collisionIndex], isFalse);
    });

    test('honors ceiling immunity on solid terrain', () {
      final world = EcsWorld();
      final projectile = _spawnBallistic(
        world,
        x: 150,
        y: 250,
        velocityY: -6000,
        body: const BodyDef(ignoreCeilings: true),
      );
      final system = TerrainBallisticProjectileSystem(
        edgeIndex: TerrainEdgeIndex(edges: solidGeometry.edges),
      );

      system.step(world, movement);

      final transformIndex = world.transform.indexOf(projectile);
      final collisionIndex = world.collision.indexOf(projectile);
      expect(world.transform.posY[transformIndex], closeTo(150, 1 / 1024));
      expect(world.collision.hitCeiling[collisionIndex], isFalse);
    });

    test('honors disabled right-side collision on solid terrain', () {
      final world = EcsWorld();
      final projectile = _spawnBallistic(
        world,
        x: 50,
        y: 150,
        velocityX: 6000,
        velocityY: 0,
        body: const BodyDef(sideMask: BodyDef.sideLeft),
      );
      final system = TerrainBallisticProjectileSystem(
        edgeIndex: TerrainEdgeIndex(edges: solidGeometry.edges),
      );

      system.step(world, movement);

      final transformIndex = world.transform.indexOf(projectile);
      final collisionIndex = world.collision.indexOf(projectile);
      expect(world.transform.posX[transformIndex], closeTo(150, 1 / 1024));
      expect(world.collision.hitRight[collisionIndex], isFalse);
    });
  });
}

int _spawnBallistic(
  EcsWorld world, {
  required double x,
  required double y,
  required double velocityY,
  double velocityX = 0,
  BodyDef body = const BodyDef(),
}) {
  final entity = world.createEntity();
  world.transform.add(
    entity,
    posX: x,
    posY: y,
    velX: velocityX,
    velY: velocityY,
  );
  world.body.add(entity, body);
  world.colliderAabb.add(entity, const ColliderAabbDef(halfX: 5, halfY: 5));
  world.collision.add(entity);
  world.projectile.add(
    entity,
    const ProjectileEntityDef(
      projectileId: ProjectileId.unknown,
      faction: Faction.player,
      owner: 1,
      dirX: 0,
      dirY: 1,
      speedUnitsPerSecond: 6000,
      damage100: 100,
      damageType: DamageType.physical,
      usePhysics: true,
    ),
  );
  return entity;
}
