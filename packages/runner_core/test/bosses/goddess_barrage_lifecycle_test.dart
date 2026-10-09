import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/collision/terrain/terrain_motion_request.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/combat_eligibility.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/boss_utility_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/voidborn_goddess_combat_system.dart';
import 'package:runner_core/ecs/systems/world_motion_authority.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spawn_service.dart';
import 'package:runner_core/util/vec2.dart';
import 'package:test/test.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test(
      'Goddess is protected through the last hand, vulnerable on return at $hz Hz',
      () {
        final f = _Fixture(hz)..cast();
        final hp = f.hp;
        f.damage(10);
        expect(f.hp, hp);
        f.prepare(11);
        final returnTick = f.returnTick;
        f.prepare(returnTick - 1);
        f.damage(returnTick - 1);
        expect(f.hp, hp);
        f.prepare(returnTick);
        expect(isCombatProtected(f.world, f.boss), isFalse);
        expect(f.world.activeAbility.hasActiveAbility(f.boss), isFalse);
        expect(f.world.goddessBarrage.returning[f.state], isTrue);
        f.damage(returnTick);
        expect(f.hp, hp - 700);
        expect(f.motion.teleports, 1);
        expect(f.world.invulnerability.has(f.boss), isFalse);

        // A terrain-blocked return releases hover after its bounded deadline;
        // it must never fall back to teleporting to the retained origin.
        final deadline = f.world.goddessBarrage.returnDeadlineTick[f.state];
        f.prepare(deadline);
        expect(f.world.goddessBarrage.has(f.boss), isFalse);
        expect(f.world.gravityControl.has(f.boss), isFalse);
        expect(f.motion.teleports, 1);
      },
    );

    for (final interruption in [
      'cancelled',
      'replaced',
      'dead',
      'stunned',
      'suspended',
    ]) {
      test(
        'Goddess releases barrage protection on $interruption at $hz Hz',
        () {
          final f = _Fixture(hz)
            ..cast()
            ..prepare(11);
          final x = f.world.transform.posX[f.transform];
          switch (interruption) {
            case 'cancelled':
              f.world.activeAbility.clear(f.boss);
            case 'replaced':
              f.world.activeAbility.set(
                f.boss,
                id: 'goddess.orb',
                slot: AbilitySlot.projectile,
                commitTick: 12,
                windupTicks: 20,
                activeTicks: 3,
                recoveryTicks: 10,
                facingDir: Facing.left,
              );
            case 'dead':
              f.world.health.hp[f.world.health.indexOf(f.boss)] = 0;
            case 'stunned':
              f.world.controlLock.addLock(f.boss, LockFlag.stun, hz, 12);
            case 'suspended':
              f.world.arenaSuspension.addEntity(f.boss);
          }
          f.prepare(12);
          expect(f.world.goddessBarrage.has(f.boss), isFalse);
          expect(isCombatProtected(f.world, f.boss), isFalse);
          expect(f.world.gravityControl.has(f.boss), isFalse);
          expect(f.world.transform.posX[f.transform], x);
          expect(f.motion.teleports, 1);
          if (interruption == 'replaced') {
            expect(
              f.world.activeAbility.abilityId[f.world.activeAbility.indexOf(
                f.boss,
              )],
              'goddess.orb',
            );
          }
        },
      );
    }

    test('Goddess casts safely when both corners are obstructed at $hz Hz', () {
      final f = _Fixture(hz);
      f.motion.accept = false;
      f.cast();
      f.prepare(11);
      expect(f.world.goddessBarrage.hovering[f.state], isFalse);
      expect(isCombatProtected(f.world, f.boss), isTrue);
      f.prepare(f.returnTick);
      expect(f.world.goddessBarrage.has(f.boss), isFalse);
      expect(isCombatProtected(f.world, f.boss), isFalse);
      expect(f.world.transform.posX[f.transform], 400);
      expect(f.motion.teleports, 0);
    });

    test(
      'Goddess orb releases in 0.45 seconds at 480 units per second at $hz Hz',
      () {
        final f = _Fixture(hz);
        f.system.step(f.world, player: f.player, currentTick: 10);
        final ii = f.world.projectileIntent.indexOf(f.boss);
        final release = f.world.projectileIntent.tick[ii];
        expect(release - 10, (.45 * hz).ceil());
        final launch = ProjectileLaunchSystem(
          projectiles: const ProjectileCatalog(),
          tickHz: hz,
        );
        launch.step(f.world, currentTick: release - 1);
        expect(f.world.projectile.denseEntities, isEmpty);
        launch.step(f.world, currentTick: release);
        final projectile = f.world.projectile.denseEntities.single;
        final pi = f.world.projectile.indexOf(projectile);
        expect(f.world.projectile.projectileId[pi], ProjectileId.goddessOrb);
        expect(f.world.projectile.speedUnitsPerSecond[pi], 480);
        expect(
          const ProjectileCatalog()
              .get(ProjectileId.shoggothOrb)
              .speedUnitsPerSecond,
          340,
        );
      },
    );
  }

  test('Barrage protection does not erase another protection owner or survive recycling', () {
    final f = _Fixture(60);
    f.world.invulnerability.add(f.boss);
    final ii = f.world.invulnerability.indexOf(f.boss);
    f.world.invulnerability.protect(ii, 1000);
    f.cast();
    f.prepare(11);
    f.prepare(f.returnTick);
    expect(f.world.invulnerability.ticksLeft[ii], 1000);
    final old = f.boss;
    f.world.destroyEntity(old);
    final next = f.world.createEntity();
    expect(next, old);
    expect(isCombatProtected(f.world, next), isFalse);
    expect(f.world.goddessBarrage.has(next), isFalse);
  });
}

class _Fixture {
  _Fixture(this.hz) {
    player = actor(EnemyId.grojib, 300);
    world.faction.faction[world.faction.indexOf(player)] = Faction.player;
    boss = actor(EnemyId.voidbornGoddess, 400);
    world.actorMotionBounds.add(
      boss,
      TerrainHorizontalBounds(minXTicks: 0, maxXTicks: 600 * 1024),
    );
    system = VoidbornGoddessCombatSystem(
      tickHz: hz,
      castCommitter: AiCastCommitter(
        tickHz: hz,
        projectiles: const ProjectileCatalog(),
        surfaceTarget: (x, y) => Vec2(x, 224),
      ),
      utilities: BossUtilitySystem(
        tickHz: hz,
        motion: motion,
        spawns: _NoSpawns(),
        groundTopY: 224,
      ),
    );
  }
  final int hz;
  final world = EcsWorld(seed: 7);
  final motion = _Motion();
  late final int boss, player;
  late final VoidbornGoddessCombatSystem system;
  int get state => world.goddessBarrage.indexOf(boss);
  int get returnTick => world.goddessBarrage.returnTick[state];
  int get transform => world.transform.indexOf(boss);
  int get hp => world.health.hp[world.health.indexOf(boss)];

  int actor(EnemyId id, double x) {
    final a = const EnemyCatalog().get(id);
    return EntityFactory(world).createEnemy(
      enemyId: id,
      posX: x,
      posY: 180,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: a.body,
      collider: a.collider,
      health: a.health,
      mana: a.mana,
      stamina: a.stamina,
    );
  }

  void cast() {
    world.health.hp[world.health.indexOf(boss)] = 27000;
    system.step(world, player: player, currentTick: 10);
  }

  void prepare(int tick) {
    const ActiveAbilityPhaseSystem().step(world, currentTick: tick);
    system.prepareBarrage(world, currentTick: tick);
    system.composeMotion(world);
  }

  void damage(int tick) {
    world.damageQueue.add(
      DamageRequest(target: boss, amount100: 700, source: player),
    );
    DamageSystem(
      invulnerabilityTicksOnHit: 0,
      rngSeed: 7,
      tickHz: hz,
    ).step(world, currentTick: tick);
  }
}

class _Motion implements WorldMotionAuthority {
  var accept = true;
  var teleports = 0;
  @override
  WorldBodyPlacementOrigin beginBodyTeleport(EcsWorld world, int entity) {
    final ti = world.transform.indexOf(entity);
    return WorldBodyPlacementOrigin(
      bodyX: world.transform.posX[ti],
      bodyY: world.transform.posY[ti],
      facing: Facing.left,
    );
  }

  @override
  bool tryCommitBodyTeleport(
    EcsWorld world,
    int entity, {
    required double bodyX,
    required double bodyY,
    required Facing facing,
  }) {
    if (!accept) return false;
    teleports++;
    world.transform.setPosXY(entity, bodyX, bodyY);
    return true;
  }

  @override
  void cancelBodyTeleport(
    EcsWorld world,
    int entity,
    WorldBodyPlacementOrigin origin,
  ) {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected terrain call');
}

class _NoSpawns implements SpawnService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected spawn');
}
