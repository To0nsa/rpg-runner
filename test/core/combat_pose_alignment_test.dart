import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/combat/combat_geometry.dart';
import 'package:runner_core/combat/combat_pose_catalog.dart';
import 'package:runner_core/combat/projectile_pose_catalog.dart';
import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/hitbox_store.dart';
import 'package:runner_core/ecs/systems/combat_hurtbox_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/projectile_pose_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/projectiles/spawn_projectile_item.dart';
import 'package:runner_core/snapshots/enums.dart';

import 'support/combat_test_support.dart';

void main() {
  final abilities = [
    'eloise.bloodletter_slash',
    'eloise.bloodletter_cleave',
    'eloise.seeker_slash',
    'npc_warrior.slash',
    'npc_huntress.stab',
    'npc_huntress.slash',
    'grojib.strike',
    'grojib.strike2',
    'hashash.strike',
    'hashash.ambush',
    'unoco.strike',
  ];
  for (final id in abilities) {
    for (final hz in [30, 60, 120]) {
      for (final speed in [.75, 1.0, 1.5]) {
        test('$id damage follows active art at $hz Hz / $speed speed', () {
          final ability = AbilityCatalog.shared.resolve(id)!;
          final profile = (ability.hitDelivery as MeleeHitDelivery).profile;
          expect(profile.frames.length, profile.timing.frameCount);
          final windup = math.max(
            1,
            (ability.windupTicks * hz / 60 / speed).ceil(),
          );
          final active = math.max(
            1,
            (ability.activeTicks * hz / 60 / speed).ceil(),
          );
          final recovery = (ability.recoveryTicks * hz / 60 / speed).ceil();
          for (
            var elapsed = 0;
            elapsed < windup + active + recovery;
            elapsed++
          ) {
            final frame = profile.timing.frameAt(
              elapsed: elapsed,
              windup: windup,
              active: active,
              recovery: recovery,
            );
            expect(
              profile.frames[frame].isNotEmpty,
              elapsed >= windup && elapsed < windup + active,
              reason: 'elapsed=$elapsed frame=$frame',
            );
          }
          if (recovery > 0) {
            expect(
              profile.timing.frameAt(
                elapsed: windup + active + recovery - 1,
                windup: windup,
                active: active,
                recovery: recovery,
              ),
              profile.frames.length - 1,
            );
          }
        });
      }
    }
  }

  test('shield holds the visible guard pose throughout protection', () {
    for (var elapsed = 2; elapsed < 182; elapsed++) {
      expect(
        CombatPoseCatalog.shield.frameAt(
          elapsed: elapsed,
          windup: 2,
          active: 180,
          recovery: 2,
        ),
        3,
      );
    }
    expect(
      CombatPoseCatalog.shield.frameAt(
        elapsed: 183,
        windup: 2,
        active: 180,
        recovery: 2,
      ),
      6,
    );
  });

  test('roll lowers vulnerable body while terrain capsule stays immutable', () {
    final world = EcsWorld();
    final player = _player(world);
    attachMissingCombatCapsules(world);
    final ci = world.worldContactCapsule.indexOf(player);
    final radius = world.worldContactCapsule.radiusTicks[ci];
    final spine = world.worldContactCapsule.verticalHalfSegmentTicks[ci];
    final ai = world.animState.indexOf(player);
    world.animState.anim[ai] = AnimKey.roll;
    world.animState.animFrame[ai] = 4;
    const CombatHurtboxSystem(tickHz: 60).step(world);
    final hurt =
        world.combatHurtbox.capsule[world.combatHurtbox.indexOf(player)]!;
    expect(hurt.minY, greaterThan(0));
    expect(world.worldContactCapsule.radiusTicks[ci], radius);
    expect(world.worldContactCapsule.verticalHalfSegmentTicks[ci], spine);
    final grid = _grid(world);
    expect(grid.targets.centerY.single - grid.targets.halfY.single, hurt.minY);
  });

  test(
    'explosion is harmless before its impact poses and misses old excess reach',
    () {
      final world = EcsWorld();
      final target = _player(world);
      attachMissingCombatCapsules(world);
      world.combatHurtbox.set(target, const CombatCapsule(0, 0, 0, 0, 3));
      final attack = world.createEntity();
      world.transform.add(attack, posX: 0, posY: 0, velX: 0, velY: 0);
      world.hitbox.add(
        attack,
        const HitboxDef(
          owner: 0,
          faction: Faction.enemy,
          damage100: 100,
          damageType: DamageType.fire,
          halfX: 0,
          halfY: 1,
          offsetX: 0,
          offsetY: 0,
          dirX: 1,
          dirY: 0,
          attachment: HitboxAttachment.worldAnchor,
          profile: CombatPoseCatalog.fireExplosion,
          spawnTick: 10,
          frameStepTicks: 3,
        ),
      );
      world.hitOnce.add(attack);
      final follow = HitboxFollowOwnerSystem();
      final hits = HitboxDamageSystem();
      for (var tick = 10; tick < 16; tick++) {
        follow.step(world, currentTick: tick);
        hits.step(world, _grid(world), currentTick: tick);
        expect(world.damageQueue.length, 0, reason: 'tick=$tick');
      }
      world.transform.setPosXY(target, 42, 0);
      follow.step(world, currentTick: 16);
      hits.step(world, _grid(world), currentTick: 16);
      expect(world.damageQueue.length, 0);
      world.transform.setPosXY(target, 0, 0);
      hits.step(world, _grid(world), currentTick: 16);
      expect(world.damageQueue.length, 1);
      follow.step(world, currentTick: 19);
      hits.step(world, _grid(world), currentTick: 19);
      expect(
        world.damageQueue.length,
        1,
        reason: 'One hit across all explosion poses.',
      );
    },
  );

  test('compound attack overlaps queue one hit per target per tick', () {
    final world = EcsWorld();
    _player(world);
    attachMissingCombatCapsules(world);
    final attack = world.createEntity();
    world.transform.add(attack, posX: 0, posY: 0, velX: 0, velY: 0);
    world.hitbox.add(
      attack,
      const HitboxDef(
        owner: 0,
        faction: Faction.enemy,
        damage100: 100,
        damageType: DamageType.physical,
        halfX: 0,
        halfY: 5,
        offsetX: 0,
        offsetY: 0,
        dirX: 1,
        dirY: 0,
        hitPolicy: HitPolicy.everyTick,
      ),
    );
    world.hitbox.capsules[0] = const [
      CombatCapsule(0, 0, 0, 0, 5),
      CombatCapsule(0, 0, 1, 0, 5),
    ];
    HitboxDamageSystem().step(world, _grid(world), currentTick: 1);
    expect(world.damageQueue.length, 1);
  });

  test('piercing fitted capsule hits crossed targets between ticks', () {
    final world = EcsWorld();
    final target = _player(world);
    world.faction.faction[world.faction.indexOf(target)] = Faction.enemy;
    world.transform.setPosXY(target, 100, 0);
    attachMissingCombatCapsules(world);
    final def = const ProjectileCatalog().get(ProjectileId.fireBolt);
    final entity = spawnProjectileFromCaster(
      world,
      tickHz: 60,
      currentTick: 50,
      projectileId: ProjectileId.fireBolt,
      projectile: def,
      faction: Faction.player,
      owner: 0,
      casterX: 0,
      casterY: 0,
      originOffset: 0,
      dirX: 1,
      dirY: 0,
      fallbackDirX: 1,
      fallbackDirY: 0,
      damage100: 100,
      critChanceBp: 0,
      damageType: def.damageType,
      ballistic: false,
      gravityScale: 0,
      pierce: true,
      maxPierceHits: 2,
    );
    final pi = world.projectile.indexOf(entity);
    world.projectile.previousX[pi] = 0;
    world.projectile.previousY[pi] = 0;
    world.transform.setPosXY(entity, 200, 0);
    const ProjectilePoseSystem(tickHz: 60).step(world, currentTick: 51);
    ProjectileHitSystem().step(world, _grid(world), currentTick: 51);
    expect(world.damageQueue.target.single, target);
    expect(world.projectile.has(entity), isTrue);
    ProjectileHitSystem().step(world, _grid(world), currentTick: 51);
    expect(world.damageQueue.length, 1);
  });

  for (final id in ProjectileId.values.where(
    (id) => id != ProjectileId.unknown && id != ProjectileId.poisonDart,
  )) {
    test('$id flight pose, collision and spawn clock agree', () {
      final world = EcsWorld();
      final def = const ProjectileCatalog().get(id);
      final entity = spawnProjectileFromCaster(
        world,
        tickHz: 60,
        currentTick: 50,
        projectileId: id,
        projectile: def,
        faction: Faction.player,
        owner: 0,
        casterX: 0,
        casterY: 0,
        originOffset: 0,
        dirX: 0,
        dirY: -1,
        fallbackDirX: 1,
        fallbackDirY: 0,
        damage100: 100,
        critChanceBp: 0,
        damageType: def.damageType,
        ballistic: false,
        gravityScale: 0,
      );
      const poses = ProjectilePoseSystem(tickHz: 60);
      final i = world.projectile.indexOf(entity);
      final render = const ProjectileRenderCatalog().get(id);
      final startTicks =
          ((render.frameCountsByKey[AnimKey.spawn] ?? 0) *
                  math.max(
                    1,
                    ((render.stepTimeSecondsByKey[AnimKey.spawn] ?? .1) * 60)
                        .round(),
                  ))
              .toInt();
      poses.step(world, currentTick: 50);
      expect(
        world.projectile.anim[i],
        startTicks > 0 ? AnimKey.spawn : AnimKey.idle,
      );
      expect(world.projectile.animFrame[i], 0);
      expect(world.projectile.combatCapsule[i], isNotNull);
      poses.step(world, currentTick: 50 + startTicks);
      expect(world.projectile.anim[i], AnimKey.idle);
      expect(world.projectile.animFrame[i], 0);
      final shape = world.projectile.combatCapsule[i]!;
      final authored = ProjectilePoseCatalog.frame(id, AnimKey.idle, 0).single;
      // Vertical aim rotates the same authored silhouette rather than mirroring it.
      expect(shape.ax, closeTo(authored.ay, 1e-9));
      expect(shape.ay, closeTo(-authored.ax, 1e-9));
      expect(shape.bx, closeTo(authored.by, 1e-9));
      expect(shape.by, closeTo(-authored.bx, 1e-9));
      expect(shape.radius, greaterThan(0));
      expect(shape.minY, lessThan(shape.maxY));
      expect(world.projectile.spawnTick[i], 50);
    });
  }
}

int _player(EcsWorld world) {
  final a = const EnemyCatalog().get(EnemyId.derf);
  return EntityFactory(world).createPlayer(
    posX: 0,
    posY: 0,
    velX: 0,
    velY: 0,
    facing: Facing.right,
    grounded: true,
    body: a.body,
    collider: a.collider,
    health: a.health,
    mana: a.mana,
    stamina: a.stamina,
  );
}

BroadphaseGrid _grid(EcsWorld world) =>
    BroadphaseGrid(index: GridIndex2D(cellSize: 64))..rebuild(world);
