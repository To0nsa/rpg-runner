import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/combat/hit_target_policy.dart';
import 'package:runner_core/ecs/hit/capsule_sweep.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/projectile_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:test/test.dart';

void main() {
  final movement = MovementTuningDerived.from(
    const MovementTuning(),
    tickHz: 60,
  );
  final motion = ProjectileSystem();
  void resolve(
    EcsWorld world, {
    int tick = 1,
    List<ProjectileHitEvent>? events,
  }) {
    final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 32))
      ..rebuild(world);
    ProjectileHitSystem().step(
      world,
      grid,
      currentTick: tick,
      queueHitEvent: events?.add,
    );
  }

  test(
    'fast projectile picks nearest contact, including reversed ID order',
    () {
      final world = EcsWorld();
      _target(world, 80);
      final near = _target(world, 30);
      final p = _projectile(world);
      final events = <ProjectileHitEvent>[];
      motion.step(world, movement);
      resolve(world, events: events);
      expect(world.damageQueue.target, [near]);
      expect(world.damageQueue.sourceEntity, [null]);
      expect(world.projectile.has(p), isFalse);
      expect(events.single.pos.x, closeTo(25, 1e-10));
    },
  );

  test('contact surface wins rather than target center distance', () {
    final world = EcsWorld();
    _target(world, 40, radius: 1);
    final large = _target(world, 50, radius: 20);
    _projectile(world);
    motion.step(world, movement);
    resolve(world);
    expect(world.damageQueue.target, [large]);
  });

  test('equal contact uses entity ID after dense swap removal', () {
    final world = EcsWorld();
    final removed = _target(world, 200);
    final first = _target(world, 50);
    _target(world, 50);
    world.destroyEntity(removed);
    _projectile(world);
    motion.step(world, movement);
    resolve(world);
    expect(world.damageQueue.target, [first]);
  });

  test(
    'environmental target policy reaches both factions but skips dead HP',
    () {
      for (final faction in Faction.values) {
        final world = EcsWorld();
        final dead = _target(world, 10, faction: faction);
        world.health.hp[world.health.indexOf(dead)] = 0;
        final target = _target(world, 30, faction: faction);
        _projectile(world, policy: HitTargetPolicy.allActors);
        motion.step(world, movement);
        resolve(world);
        expect(world.damageQueue.target, [target]);
      }
    },
  );

  test('ordinary friendly fire stays disabled', () {
    final world = EcsWorld();
    _target(world, 10, faction: Faction.player);
    final enemy = _target(world, 60);
    _projectile(world);
    motion.step(world, movement);
    resolve(world);
    expect(world.damageQueue.target, [enemy]);
  });

  test(
    'deferred first hit includes muzzle overlap on its first moved sweep',
    () {
      final world = EcsWorld();
      final target = _target(world, 0, faction: Faction.player);
      final p = _projectile(
        world,
        firstHitTick: 2,
        policy: HitTargetPolicy.allActors,
      );
      resolve(world, tick: 1);
      expect(world.projectile.has(p), isTrue);
      expect(world.damageQueue.length, 0);
      motion.step(world, movement);
      final events = <ProjectileHitEvent>[];
      resolve(world, tick: 2, events: events);
      expect(world.damageQueue.target, [target]);
      expect(events.single.pos.x, 0);
    },
  );

  test('ordinary launches still hit overlapping targets on launch tick', () {
    final world = EcsWorld();
    final target = _target(world, 0);
    _projectile(world);
    resolve(world);
    expect(world.damageQueue.target, [target]);
  });

  test('physics capture retains pre-motion origin across direction update', () {
    final world = EcsWorld();
    final target = _target(world, 50);
    final p = _projectile(world, physics: true);
    motion.capturePhysicsPositions(world);
    final ti = world.transform.indexOf(p);
    world.transform.posX[ti] = 100;
    world.transform.velX[ti] = 6000;
    motion.step(world, movement);
    resolve(world);
    expect(world.damageQueue.target, [target]);
  });

  test('sweep handles transverse shaft contact and exact end-cap tangency', () {
    expect(
      capsuleSweepFirstContact(
        ax: -10,
        ay: 0,
        bx: 10,
        by: 0,
        radius: 1,
        deltaX: 0,
        deltaY: 20,
        targetAx: 0,
        targetAy: 10,
        targetBx: 0,
        targetBy: 10,
        targetRadius: 1,
      ),
      0.4,
    );
    expect(
      capsuleSweepFirstContact(
        ax: 0,
        ay: 0,
        bx: 0,
        by: 0,
        radius: 1,
        deltaX: 20,
        deltaY: 0,
        targetAx: 10,
        targetAy: 2,
        targetBx: 10,
        targetBy: 2,
        targetRadius: 1,
      ),
      0.5,
    );
    expect(
      capsuleSweepFirstContact(
        ax: 0,
        ay: 0,
        bx: 0,
        by: 0,
        radius: 1,
        deltaX: 20,
        deltaY: 0,
        targetAx: 10,
        targetAy: 2.01,
        targetBx: 10,
        targetBy: 2.01,
        targetRadius: 1,
      ),
      isNull,
    );
  });

  test(
    'second tick uses last position, never the original launch position',
    () {
      final world = EcsWorld();
      _projectile(world);
      motion.step(world, movement);
      resolve(world);
      _target(world, 40);
      motion.step(world, movement);
      resolve(world, tick: 2);
      expect(world.damageQueue.length, 0);
    },
  );
}

int _target(
  EcsWorld world,
  double x, {
  double radius = 2,
  Faction faction = Faction.enemy,
}) {
  final e = world.createEntity();
  world.transform.add(e, posX: x, posY: 0, velX: 0, velY: 0);
  world.colliderAabb.add(e, ColliderAabbDef(halfX: radius, halfY: radius + 4));
  world.worldContactCapsule.add(
    e,
    WorldContactCapsuleDef(radius: radius, verticalHalfSegment: 4),
  );
  world.health.add(
    e,
    const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
  );
  world.faction.add(e, FactionDef(faction: faction));
  return e;
}

int _projectile(
  EcsWorld world, {
  int firstHitTick = 0,
  HitTargetPolicy policy = HitTargetPolicy.hostile,
  bool physics = false,
}) {
  final e = world.createEntity();
  world.transform.add(e, posX: 0, posY: 0, velX: 0, velY: 0);
  world.colliderAabb.add(e, const ColliderAabbDef(halfX: 2, halfY: 1));
  world.projectile.add(
    e,
    ProjectileEntityDef(
      projectileId: ProjectileId.fireBolt,
      faction: Faction.player,
      owner: 0,
      dirX: 1,
      dirY: 0,
      speedUnitsPerSecond: 6000,
      damage100: 100,
      damageType: DamageType.fire,
      firstHitTick: firstHitTick,
      targetPolicy: policy,
      usePhysics: physics,
    ),
  );
  return e;
}
