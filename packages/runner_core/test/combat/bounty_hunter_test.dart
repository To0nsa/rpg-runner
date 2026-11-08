import 'package:runner_core/ecs/systems/reactive_proc_system.dart';
import 'package:runner_core/weapons/weapon_proc.dart';

import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/tuning/physics_tuning.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/abilities/catalog/bounty_hunter_ability_defs.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/collision/terrain/terrain_compiler.dart';
import 'package:runner_core/collision/terrain/terrain_edge_index.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/combat/damage.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/combat/projectile_aim_visibility.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/ecs/stores/faction_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ability_activation_system.dart';
import 'package:runner_core/ecs/systems/player_movement_system.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/systems/projectile_world_collision_system.dart';
import 'package:runner_core/ecs/systems/terrain_ballistic_projectile_system.dart';
import 'package:runner_core/ecs/systems/gravity_system.dart';
import 'package:runner_core/ecs/systems/bomb_system.dart';
import 'package:runner_core/ecs/systems/self_ability_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/systems/target_mark_system.dart';
import 'package:runner_core/ecs/systems/jump_system.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/anim/anim_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/melee_strike_system.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/combat_lunge_system.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/loadout/loadout_validator.dart';
import 'package:runner_core/loadout/loadout_issue.dart';
import 'package:runner_core/players/characters/bounty_hunter.dart';
import 'package:runner_core/players/characters/bounty_hunter_geometry.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/spellBook/spell_book_id.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:runner_core/weapons/weapon_id.dart';

const _loadout = EquippedLoadoutDef(
  mask: LoadoutSlotMask.all,
  mainWeaponId: WeaponId.hunterBlade,
  offhandWeaponId: WeaponId.hunterBombKit,
  spellBookId: SpellBookId.hunterFieldKit,
  projectileSlotSpellId: ProjectileId.hunterPistol,
  abilityPrimaryId: 'bounty_hunter.quick_cut',
  abilitySecondaryId: 'bounty_hunter.blast_bomb',
  abilityProjectileId: 'bounty_hunter.snap_shot',
  abilitySpellId: 'bounty_hunter.hunters_focus',
  abilityMobilityId: 'bounty_hunter.dash',
  abilityJumpId: 'bounty_hunter.jump',
);

void main() {
  for (final tickHz in [30, 60, 120]) {
    for (final kit in [WeaponId.hunterSplinterRig, WeaponId.hunterPitchRig]) {
      test(
        '$kit critical blast applies authored damage-over-time at $tickHz Hz',
        () {
          final h = _Harness(tickHz: tickHz);
          final target = h.enemy(10, 28);
          h.world.equippedLoadout.offhandWeaponId[0] = kit;
          h.press(AbilitySlot.secondary);
          h.world.projectileIntent.critChanceBp[0] = 10000;
          h.launch.step(h.world, currentTick: h.world.projectileIntent.tick[0]);
          final fuse = h.world.bomb.explodeTick.single;
          final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64))
            ..rebuild(h.world);
          BombSystem(
            tickHz: tickHz,
            pathClear: (_, _, _, _) => true,
          ).step(h.world, grid, currentTick: fuse);
          final status = StatusSystem(tickHz: tickHz);
          DamageSystem(
            invulnerabilityTicksOnHit: 0,
            rngSeed: 1,
            tickHz: tickHz,
          ).step(h.world, currentTick: fuse, queueStatus: status.queue);
          status.applyQueued(h.world, currentTick: fuse);
          final i = h.world.dot.indexOf(target);
          expect(h.world.dot.dps100[i], [200]);
          expect(h.world.dot.ticksLeft[i], [3 * tickHz]);
          expect(
            h.world.health.hp[h.world.health.indexOf(target)],
            lessThan(10000),
          );
        },
      );
    }
    test(
      'Backtrail Rig requires a health crossing and waits 30s at $tickHz Hz',
      () {
        final h = _Harness(tickHz: tickHz);
        h.world.equippedLoadout.offhandWeaponId[0] =
            WeaponId.hunterBacktrailRig;
        final damage = DamageSystem(
          invulnerabilityTicksOnHit: 0,
          rngSeed: 1,
          tickHz: tickHz,
        );
        final reactive = ReactiveProcSystem(
          weapons: const WeaponCatalog(),
          rngSeed: 1,
          tickHz: tickHz,
        );
        final queued = <StatusRequest>[];
        void hit(int tick, {bool heal = true}) {
          if (heal) h.world.health.hp[0] = 3500;
          h.world.damageQueue.add(
            DamageRequest(target: h.player, amount100: 1200),
          );
          damage.step(h.world, currentTick: tick);
          reactive.step(h.world, currentTick: tick, queueStatus: queued.add);
        }

        hit(1);
        expect(queued, hasLength(1));
        final statuses = StatusSystem(tickHz: tickHz)..queue(queued.single);
        statuses.applyQueued(h.world, currentTick: 1);
        expect(h.world.haste.magnitude.single, 1500);
        expect(h.world.haste.ticksLeft.single, 3 * tickHz);
        hit(2, heal: false);
        hit(30 * tickHz);
        expect(queued, hasLength(1));
        hit(30 * tickHz + 1);
        expect(queued, hasLength(2));
      },
    );
  }
  test('blade effects stay out of gun and bomb payloads', () {
    for (final slot in [
      AbilitySlot.primary,
      AbilitySlot.projectile,
      AbilitySlot.secondary,
    ]) {
      final h = _Harness();
      h.world.equippedLoadout.mainWeaponId[0] = WeaponId.hunterNotchknife;
      h.world.equippedLoadout.offhandWeaponId[0] = WeaponId.hunterSnareRig;
      h.press(slot);
      final procs = slot == AbilitySlot.primary
          ? h.world.meleeIntent.procs.single
          : h.world.projectileIntent.procs.single;
      expect(procs.map((p) => p.statusProfileId), switch (slot) {
        AbilitySlot.primary => [StatusProfileId.meleeBleed],
        AbilitySlot.secondary => [StatusProfileId.slowOnHit],
        _ => isEmpty,
      });
    }
  });
  test('bomb kit and ability effects retain distinct hook tuning', () {
    final h = _Harness();
    h.world.equippedLoadout.offhandWeaponId[0] = WeaponId.hunterPitchRig;
    h.equip(bountyHunterAbilityDefs['bounty_hunter.fire_bomb']!);
    h.press(AbilitySlot.secondary);
    final procs = h.world.projectileIntent.procs.single;
    expect(procs.where((p) => p.hook == ProcHook.onHit), hasLength(1));
    expect(procs.where((p) => p.hook == ProcHook.onCrit), hasLength(1));
    final critical = procs.singleWhere((p) => p.hook == ProcHook.onCrit);
    expect(critical.statusTuning.dot!.magnitude, 200);
  });

  for (final gun in hunterRangedWeaponIds) {
    for (final hz in [30, 60, 120]) {
      for (final facing in Facing.values) {
        test('$gun moving auto aim keeps its muzzle, $facing at $hz Hz', () {
          for (final targetX in [-160.0, -45.0, -5.0, 5.0, 45.0, 160.0]) {
            final rays = <(double, double)>[];
            final h = _Harness(
              tickHz: hz,
              weapon: gun,
              aimPathClear: (x, y, _, _) {
                rays.add((x, y));
                return true;
              },
            );
            final movement = PlayerMovementSystem();
            h.world.playerInput.moveAxis[0] = facing == Facing.right ? 1 : -1;
            // Reach steady speed so this isolates facing from acceleration lead.
            for (var tick = -60; tick < 0; tick++) {
              movement.step(h.world, h.movement, currentTick: tick);
            }
            h.enemy(targetX, 20);
            h.press(AbilitySlot.projectile);
            final aimedFacing = h.world.movement.facing[0];
            final release = h.world.projectileIntent.tick.single;
            for (var tick = 1; tick <= release; tick++) {
              const ActiveAbilityPhaseSystem().step(h.world, currentTick: tick);
              movement.step(h.world, h.movement, currentTick: tick);
              expect(h.world.movement.facing[0], aimedFacing);
              // Free motion matches this harness's gravity-free, terrain-free body.
              h.world.transform.posX[0] += h.world.transform.velX[0] / hz;
              h.launch.step(h.world, currentTick: tick);
            }
            final projectiles = h.world.projectile;
            expect(projectiles.denseEntities, isNotEmpty);
            expect(rays, hasLength(1));
            for (final entity in projectiles.denseEntities) {
              final ti = h.world.transform.indexOf(entity);
              expect(h.world.transform.posX[ti], closeTo(rays.single.$1, 1e-9));
              expect(h.world.transform.posY[ti], closeTo(rays.single.$2, 1e-9));
            }
            final middle = projectiles.denseEntities.length ~/ 2;
            final dx = targetX - rays.single.$1, dy = 20 - rays.single.$2;
            final length = math.sqrt(dx * dx + dy * dy);
            expect(projectiles.dirX[middle], closeTo(dx / length, 1e-9));
            expect(projectiles.dirY[middle], closeTo(dy / length, 1e-9));
            // Release relinquishes facing without waiting for action recovery.
            movement.step(h.world, h.movement, currentTick: release + 1);
            expect(h.world.movement.facing[0], facing);
          }
        });
        test('$gun releases from its visible muzzle, $facing at $hz Hz', () {
          final character = bountyHunterCharacter.withProjectile(gun);
          final render = character.renderAnim;
          final step = math.max(
            1,
            (render.stepTimeSecondsByKey[AnimKey.rangedRun]! * hz).round(),
          );
          for (final posture in ['standing', 'air', 'run']) {
            for (
              var runFrame = 0;
              runFrame < (posture == 'run' ? 8 : 1);
              runFrame++
            ) {
              final h = _Harness(tickHz: hz, weapon: gun);
              h.equip(bountyHunterAbilityDefs['bounty_hunter.scatter_shot']!);
              h.world.movement.facing[0] = facing;
              final sign = facing == Facing.right ? 1.0 : -1.0;
              h.press(
                AbilitySlot.projectile,
                aimX: sign * .6,
                aimY: -.8,
                tick: 1 + runFrame * step,
              );
              final release = h.world.projectileIntent.tick.single;
              // Move and change posture during windup: attachments use release
              // state, never the body position/posture captured at commit.
              final tick = release;
              h.world.collision.grounded[0] = posture != 'air';
              h.world.transform.setPosXY(h.player, 80, 70);
              h.world.transform.velX[0] = posture == 'run' ? 160 : 0;
              const ActiveAbilityPhaseSystem().step(h.world, currentTick: tick);
              h.launch.step(h.world, currentTick: tick);
              AnimSystem(
                tickHz: hz,
                playerRenderAnim: render,
                enemyCatalog: const EnemyCatalog(),
                playerMovement: h.movement,
                playerAnimTuning: AnimTuningDerived.from(
                  bountyHunterTuning.anim,
                  tickHz: hz,
                  renderAnim: render,
                ),
              ).step(
                h.world,
                player: h.player,
                currentTick: tick,
                playerSpawnStartTick: -1000,
              );
              final anim = h.world.animState.anim.single;
              final visible =
                  h.world.animState.animFrame.single ~/
                  math.max(
                    1,
                    (render.stepTimeSecondsByKey[anim]! * hz).round(),
                  );
              expect(
                anim,
                posture == 'standing'
                    ? AnimKey.ranged
                    : posture == 'air'
                    ? AnimKey.rangedAir
                    : AnimKey.rangedRun,
              );
              expect(posture == 'run' ? visible ~/ 8 : visible, 1);
              final profile = character.projectileMuzzles[gun]!;
              final offset = posture == 'standing'
                  ? profile.standing
                  : posture == 'air'
                  ? profile.airborne
                  : profile.running[visible % 8];
              final entities = h.world.projectile.denseEntities;
              expect(entities, hasLength(5));
              for (final entity in entities) {
                final ti = h.world.transform.indexOf(entity);
                expect(
                  h.world.transform.posX[ti],
                  closeTo(80 + offset.x * sign, 1e-9),
                );
                expect(
                  h.world.transform.posY[ti],
                  closeTo(70 + offset.y, 1e-9),
                );
              }
              expect(
                h.world.projectile.dirY.first,
                isNot(closeTo(h.world.projectile.dirY.last, 1e-6)),
              );
              // A consumed release cannot emit a second fan.
              h.launch.step(h.world, currentTick: tick);
              expect(h.world.projectile.denseEntities, hasLength(5));
            }
          }
        });
      }
    }
    for (final targetX in [-160.0, -5.0, 5.0, 160.0]) {
      test(
        '$gun auto aim starts its trajectory and sightline at the muzzle, x=$targetX',
        () {
          final rays = <(double, double)>[];
          final h = _Harness(
            weapon: gun,
            aimPathClear: (x, y, _, _) {
              rays.add((x, y));
              return true;
            },
          );
          h.enemy(targetX, 20);
          h.press(AbilitySlot.projectile);
          h.launch.step(
            h.world,
            currentTick: h.world.projectileIntent.tick.single,
          );
          final projectiles = h.world.projectile;
          // The middle pellet retains the exact aimed direction for fan weapons.
          final middle = projectiles.denseEntities.length ~/ 2;
          final ti = h.world.transform.indexOf(
            projectiles.denseEntities[middle],
          );
          final x = h.world.transform.posX[ti], y = h.world.transform.posY[ti];
          expect(rays, hasLength(1));
          expect(rays.single.$1, closeTo(x, 1e-9));
          expect(rays.single.$2, closeTo(y, 1e-9));
          final dx = targetX - x, dy = 20 - y;
          final length = math.sqrt(dx * dx + dy * dy);
          expect(projectiles.dirX[middle], closeTo(dx / length, 1e-9));
          expect(projectiles.dirY[middle], closeTo(dy / length, 1e-9));
          expect(
            h.world.movement.facing.single,
            targetX < 0 ? Facing.left : Facing.right,
          );
        },
      );
    }
  }
  for (final name in [
    'quick_shot',
    'piercing_shot',
    'scatter_shot',
    'charged_shot',
  ]) {
    test('$name retains manual and vertical facing through release', () {
      for (final aimX in [-1.0, 0.0]) {
        for (final actionSpeed in [5000, 15000]) {
          final h = _Harness();
          h.equip(bountyHunterAbilityDefs['bounty_hunter.$name']!);
          h.world.statModifier.actionSpeedBp[0] = actionSpeed;
          h.world.playerInput.moveAxis[0] = -1;
          h.press(AbilitySlot.projectile, aimX: aimX, aimY: -1);
          h.world.playerInput.moveAxis[0] = 1;
          final movement = PlayerMovementSystem();
          final release = h.world.projectileIntent.tick.single;
          for (var tick = 1; tick <= release; tick++) {
            movement.step(h.world, h.movement, currentTick: tick);
            expect(h.world.movement.facing[0], Facing.left);
            h.launch.step(h.world, currentTick: tick);
          }
          expect(h.world.projectile.denseEntities, isNotEmpty);
          movement.step(h.world, h.movement, currentTick: release + 1);
          expect(h.world.movement.facing[0], Facing.right);
        }
      }
    });
  }
  test('mobility cancellation immediately releases pending shot facing', () {
    final h = _Harness();
    h.enemy(-160, 20);
    h.press(AbilitySlot.projectile);
    final release = h.world.projectileIntent.tick.single;
    h.world.playerInput.moveAxis[0] = 1;
    h.press(AbilitySlot.mobility, tick: 2);
    PlayerMovementSystem().step(h.world, h.movement, currentTick: 2);
    expect(h.world.movement.facing[0], Facing.right);
    expect(h.world.movement.facingLockTicksLeft[0], 0);
    h.launch.step(h.world, currentTick: release);
    expect(h.world.projectile.denseEntities, isEmpty);
  });
  test('bomb windup does not reserve weapon-tip facing', () {
    final h = _Harness();
    h.press(AbilitySlot.secondary);
    h.world.playerInput.moveAxis[0] = -1;
    PlayerMovementSystem().step(h.world, h.movement, currentTick: 1);
    expect(h.world.movement.facing[0], Facing.left);
  });
  for (final name in [
    'hunters_focus',
    'forced_march',
    'field_dressing',
    'second_wind',
    'prepare_charges',
  ]) {
    test(
      '$name applies its fieldcraft effect and spends the right resource',
      () {
        final h = _Harness();
        h.world.health.hp[0] = 5000;
        h.world.mana.mana[0] = 5000;
        h.world.stamina.stamina[0] = 5000;
        final def = bountyHunterAbilityDefs['bounty_hunter.$name']!;
        h.equip(def);
        h.press(AbilitySlot.spell);
        final statuses = StatusSystem(tickHz: 60);
        SelfAbilitySystem().step(
          h.world,
          currentTick: 1,
          queueStatus: statuses.queue,
        );
        statuses.applyQueued(h.world, currentTick: 1);
        expect(h.world.mana.mana[0], 5000 - def.defaultCost.manaCost100);
        expect(
          h.world.stamina.stamina[0],
          5000 - def.defaultCost.staminaCost100,
        );
        if (name == 'hunters_focus') {
          expect(h.world.offenseBuff.has(h.player), isTrue);
        }
        if (name == 'forced_march') {
          expect(h.world.haste.has(h.player), isTrue);
        }
        for (var tick = 2; tick <= 301; tick++) {
          statuses.tickExisting(h.world);
          statuses.applyQueued(h.world, currentTick: tick);
        }
        switch (name) {
          case 'field_dressing':
            expect(h.world.health.hp[0], greaterThan(5000));
          case 'second_wind':
            expect(h.world.stamina.stamina[0], greaterThan(5000));
          case 'prepare_charges':
            expect(h.world.mana.mana[0], greaterThan(5000));
        }
      },
    );
  }
  test('Antidote can commit while stunned and purges damage over time', () {
    final h = _Harness();
    final statuses = StatusSystem(tickHz: 60);
    for (final profile in [
      StatusProfileId.stunOnHit,
      StatusProfileId.burnOnHit,
    ]) {
      statuses.queue(StatusRequest(target: h.player, profileId: profile));
    }
    statuses.applyQueued(h.world, currentTick: 0);
    expect(h.world.controlLock.isLocked(h.player, LockFlag.stun, 1), isTrue);
    h.equip(bountyHunterAbilityDefs['bounty_hunter.antidote']!);
    h.press(AbilitySlot.spell);
    SelfAbilitySystem().step(
      h.world,
      currentTick: 1,
      queuePurge: statuses.queuePurge,
    );
    statuses.tickExisting(h.world);
    expect(h.world.controlLock.isLocked(h.player, LockFlag.stun, 1), isFalse);
    expect(h.world.dot.has(h.player), isFalse);
    expect(h.world.mana.mana[0], 8600);
  });
  for (final name in ['shrapnel_bomb', 'fire_bomb', 'concussion_bomb']) {
    test('$name applies its status through an accepted blast hit', () {
      final h = _Harness();
      final target = h.enemy(10, 28);
      h.equip(bountyHunterAbilityDefs['bounty_hunter.$name']!);
      h.press(AbilitySlot.secondary);
      h.launch.step(h.world, currentTick: h.world.projectileIntent.tick[0]);
      final fuse = h.world.bomb.explodeTick.single;
      final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64))
        ..rebuild(h.world);
      BombSystem(
        tickHz: 60,
        pathClear: (_, _, _, _) => true,
      ).step(h.world, grid, currentTick: fuse);
      final statuses = StatusSystem(tickHz: 60);
      DamageSystem(
        invulnerabilityTicksOnHit: 0,
        rngSeed: 1,
      ).step(h.world, currentTick: fuse, queueStatus: statuses.queue);
      statuses.applyQueued(h.world, currentTick: fuse);
      expect(
        h.world.health.hp[h.world.health.indexOf(target)],
        lessThan(10000),
      );
      if (name == 'concussion_bomb') {
        expect(
          h.world.controlLock.isLocked(target, LockFlag.stun, fuse),
          isTrue,
        );
      } else {
        expect(h.world.dot.has(target), isTrue);
      }
    });
  }
  test(
    'damage interrupts a committed charged shot before its projectile releases',
    () {
      final h = _Harness();
      h.equip(bountyHunterAbilityDefs['bounty_hunter.charged_shot']!);
      h.press(AbilitySlot.projectile);
      final release = h.world.projectileIntent.tick[0];
      h.world.damageQueue.add(DamageRequest(target: h.player, amount100: 100));
      DamageSystem(
        invulnerabilityTicksOnHit: 0,
        rngSeed: 1,
      ).step(h.world, currentTick: 2);
      h.world.playerInput.moveAxis[0] = -1;
      PlayerMovementSystem().step(h.world, h.movement, currentTick: 2);
      expect(h.world.movement.facing[0], Facing.left);
      expect(h.world.movement.facingLockTicksLeft[0], 0);
      h.launch.step(h.world, currentTick: release);
      expect(h.world.activeAbility.hasActiveAbility(h.player), isFalse);
      expect(h.world.projectile.denseEntities, isEmpty);
    },
  );
  for (final hz in [30, 60, 120]) {
    for (final (name, swings) in [
      ('quick_cut', 1),
      ('twin_cut', 2),
      ('lunge_slash', 1),
    ]) {
      test('$name damages each visible swing once at $hz Hz', () {
        final h = _Harness(tickHz: hz);
        // Keep the target in the shared sweep region of the scaled blade art.
        final target = h.enemy(30 * bountyHunterWorldScale, 20);
        h.equip(bountyHunterAbilityDefs['bounty_hunter.$name']!);
        h.press(AbilitySlot.primary);
        h.world.meleeIntent.critChanceBp[0] = 0;
        final damage = h.world.meleeIntent.damage100[0];
        final render = bountyHunterCharacter.renderAnim;
        final anim = AnimSystem(
          tickHz: hz,
          playerRenderAnim: render,
          enemyCatalog: const EnemyCatalog(),
          playerMovement: h.movement,
          playerAnimTuning: AnimTuningDerived.from(
            bountyHunterTuning.anim,
            tickHz: hz,
            renderAnim: render,
          ),
        );
        final follow = HitboxFollowOwnerSystem(
          tickHz: hz,
          playerRenderAnim: render,
        );
        final hits = HitboxDamageSystem();
        final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
        final apply = DamageSystem(
          invulnerabilityTicksOnHit: 0,
          rngSeed: 1,
          tickHz: hz,
        );
        var count = 0;
        final hitFrames = <int>[];
        for (var tick = 1; tick <= hz + 1; tick++) {
          const ActiveAbilityPhaseSystem().step(h.world, currentTick: tick);
          MeleeStrikeSystem().step(h.world, currentTick: tick);
          anim.step(
            h.world,
            player: h.player,
            currentTick: tick,
            playerSpawnStartTick: -1000,
          );
          follow.step(h.world, currentTick: tick);
          grid.rebuild(h.world);
          hits.step(h.world, grid, currentTick: tick);
          if (h.world.damageQueue.length > 0) {
            final ai = h.world.animState.indexOf(h.player);
            final key = h.world.animState.anim[ai];
            final step = math.max(
              1,
              (render.stepTimeSecondsByKey[key]! * hz).round(),
            );
            hitFrames.add(h.world.animState.animFrame[ai] ~/ step);
          }
          count += h.world.damageQueue.length;
          apply.step(h.world, currentTick: tick);
        }
        expect(count, swings);
        if (name == 'twin_cut') {
          expect(hitFrames, [3, 6]);
          expect(h.world.projectile.denseEntities, isEmpty);
        }
        expect(
          h.world.health.hp[h.world.health.indexOf(target)],
          10000 - swings * damage,
        );
      });
    }
  }
  test(
    'lunge velocity applies only in active frames and never grants protection',
    () {
      final h = _Harness();
      h.equip(bountyHunterAbilityDefs['bounty_hunter.lunge_slash']!);
      h.press(AbilitySlot.primary);
      final windup = h.world.activeAbility.windupTicks[0];
      final end = windup + h.world.activeAbility.activeTicks[0];
      for (var elapsed = 0; elapsed <= end; elapsed++) {
        const ActiveAbilityPhaseSystem().step(
          h.world,
          currentTick: 1 + elapsed,
        );
        h.world.transform.velX[0] = 0;
        const CombatLungeSystem().step(h.world);
        expect(
          h.world.transform.velX[0],
          elapsed >= windup && elapsed < end ? 360 : 0,
        );
        expect(h.world.invulnerability.ticksLeft[0], 0);
      }
    },
  );
  test(
    'bomb kit works without the projectile slot and survives owner removal',
    () {
      final h = _Harness();
      h.world.equippedLoadout.mask[0] = LoadoutSlotMask.offHand;
      h.press(AbilitySlot.secondary);
      final release = h.world.projectileIntent.tick[0];
      expect(release, greaterThan(1));
      h.launch.step(h.world, currentTick: release);
      final bomb = h.world.bomb.denseEntities.single;
      h.world.destroyEntity(h.player);
      expect(h.world.bomb.has(bomb), isTrue);
      expect(h.world.projectile.owner[h.world.projectile.indexOf(bomb)], 0);
    },
  );
  test('complete roster and valid starter loadout', () {
    expect(bountyHunterAbilityDefs.length, 24);
    expect(
      AbilityCatalog.shared.resolve('bounty_hunter.threefold_cut'),
      isNull,
    );
    for (final gun in hunterRangedWeaponIds) {
      expect(
        bountyHunterCharacter.withProjectile(gun).renderAnim.sourcesByKey,
        isNot(contains(AnimKey.tripleStrike)),
      );
    }
    final validation = const LoadoutValidator(
      abilityCatalog: AbilityCatalog.shared,
      weaponCatalog: WeaponCatalog(),
      projectileCatalog: ProjectileCatalog(),
      spellBookCatalog: SpellBookCatalog(),
    ).validate(_loadout);
    expect(validation.isValid, isTrue, reason: validation.issues.toString());
  });
  test('removed Threefold Cut is rejected by loadout validation', () {
    final validation =
        const LoadoutValidator(
          abilityCatalog: AbilityCatalog.shared,
          weaponCatalog: WeaponCatalog(),
          projectileCatalog: ProjectileCatalog(),
          spellBookCatalog: SpellBookCatalog(),
        ).validate(
          EquippedLoadoutDef(
            mask: _loadout.mask,
            mainWeaponId: _loadout.mainWeaponId,
            offhandWeaponId: _loadout.offhandWeaponId,
            spellBookId: _loadout.spellBookId,
            projectileSlotSpellId: _loadout.projectileSlotSpellId,
            abilityPrimaryId: 'bounty_hunter.threefold_cut',
            abilitySecondaryId: _loadout.abilitySecondaryId,
            abilityProjectileId: _loadout.abilityProjectileId,
            abilitySpellId: _loadout.abilitySpellId,
            abilityMobilityId: _loadout.abilityMobilityId,
            abilityJumpId: _loadout.abilityJumpId,
          ),
        );
    expect(validation.isValid, isFalse);
    expect(validation.issues.single.kind, IssueKind.catalogMissing);
    expect(validation.issues.single.abilityId, 'bounty_hunter.threefold_cut');
  });
  // Blink commits require real terrain authority, covered by willow_blink_test.
  for (final ability in bountyHunterAbilityDefs.values.where(
    (a) => a.blinkMobility == null,
  )) {
    test('${ability.id} commits in its declared slot', () {
      final h = _Harness();
      h.enemy(80, 20);
      h.equip(ability);
      h.press(ability.allowedSlots.single);
      if (ability.allowedSlots.single == AbilitySlot.jump) {
        JumpSystem(abilities: AbilityCatalog.shared)
            .step(h.world, h.movement, currentTick: 1);
        expect(h.world.transform.velY[0], lessThan(0));
      } else {
        expect(h.world.activeAbility.abilityId[0], ability.id);
      }
    });
  }
  for (final weapon in hunterRangedWeaponIds) {
    for (final name in [
      'snap_shot',
      'quick_shot',
      'piercing_shot',
      'scatter_shot',
      'charged_shot',
    ]) {
      test('$weapon $name releases deterministic bounded fan', () {
        final h = _Harness();
        final ability = bountyHunterAbilityDefs['bounty_hunter.$name']!;
        h.world.equippedLoadout.projectileSlotSpellId[0] = weapon;
        h.equip(ability);
        h.press(AbilitySlot.projectile);
        final intent = h.world.projectileIntent;
        final expected =
            intent.damage100[0] *
            const ProjectileCatalog().get(weapon).damageScaleBp ~/
            10000;
        h.launch.step(h.world, currentTick: intent.tick[0]);
        final p = h.world.projectile;
        expect(p.projectileId, everyElement(weapon));
        expect(p.damage100.fold<int>(0, (a, b) => a + b), expected);
        expect(
          p.denseEntities.length,
          name == 'scatter_shot'
              ? 5
              : const ProjectileCatalog().get(weapon).shotCount,
        );
        expect(p.dirY.first, closeTo(-p.dirY.last, 1e-10));
        if (name == 'piercing_shot') expect(p.pierce, everyElement(isTrue));
      });
    }
  }
  for (final tickHz in [30, 60, 120]) {
    test(
      'bomb lands, ignores contact/allies/walls, detonates exactly once at $tickHz Hz',
      () {
        final h = _Harness(tickHz: tickHz);
        h.world.mana.mana[0] = 0;
        h.world.stamina.stamina[0] = 0;
        h.press(AbilitySlot.secondary);
        final release = h.world.projectileIntent.tick[0];
        h.launch.step(h.world, currentTick: release);
        final bomb = h.world.bomb.denseEntities.single;
        final fuse = h.world.bomb.explodeTick.single;
        expect(fuse - release, tickHz);
        expect(h.world.mana.mana[0], 0);
        expect(h.world.stamina.stamina[0], 0);
        final clear = h.enemy(-30, 82);
        final blocked = h.enemy(40, 82);
        final ally = h.enemy(-15, 82, faction: Faction.player);
        final geometry = const TerrainCompiler().compile([
          _polygon('floor', [(-200, 100), (200, 100), (200, 130), (-200, 130)]),
          _polygon('wall', [(20, 0), (23, 0), (23, 100), (20, 100)]),
        ], geometryVersion: 1);
        final index = TerrainEdgeIndex(edges: geometry.edges);
        final motion = TerrainBallisticProjectileSystem(edgeIndex: index);
        final system = BombSystem(
          tickHz: tickHz,
          pathClear: ProjectileAimVisibility(
            () => index,
            blockOneWay: false,
          ).isClear,
        );
        final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
        for (var tick = release; tick <= fuse + 3; tick++) {
          if (tick > release) {
            GravitySystem().step(
              h.world,
              h.movement,
              physics: const PhysicsTuning(),
            );
            motion.step(h.world, h.movement);
          }
          ProjectileWorldCollisionSystem().step(h.world);
          grid.rebuild(h.world);
          ProjectileHitSystem().step(h.world, grid, currentTick: tick);
          system.step(h.world, grid, currentTick: tick);
          if (tick < fuse) expect(h.world.damageQueue.length, 0);
        }
        expect(h.world.projectile.has(bomb), isTrue);
        expect(
          h.world.transform.posY[h.world.transform.indexOf(bomb)],
          closeTo(97, .01),
        );
        expect(h.world.damageQueue.target, [clear]);
        expect(h.world.damageQueue.target, isNot(contains(blocked)));
        expect(h.world.damageQueue.target, isNot(contains(ally)));
        expect(
          h.world.projectile.anim[h.world.projectile.indexOf(bomb)],
          AnimKey.bombExplosion,
        );
      },
    );
  }
  test('removed roll and slide are rejected by loadout validation', () {
    for (final name in ['roll', 'slide']) {
      final id = 'bounty_hunter.$name';
      expect(AbilityCatalog.shared.resolve(id), isNull);
      final validation = const LoadoutValidator(
        abilityCatalog: AbilityCatalog.shared,
        weaponCatalog: WeaponCatalog(),
        projectileCatalog: ProjectileCatalog(),
        spellBookCatalog: SpellBookCatalog(),
      ).validate(EquippedLoadoutDef(abilityMobilityId: id));
      expect(validation.isValid, isFalse);
      expect(
        validation.issues.any((issue) => issue.slot == AbilitySlot.mobility),
        isTrue,
      );
    }
  });
  test(
    'quarry bonus belongs to attacker and expires without recycling leaks',
    () {
      final h = _Harness();
      final target = h.enemy(40, 20);
      final other = h.enemy(80, 20, faction: Faction.player);
      h.equip(bountyHunterAbilityDefs['bounty_hunter.mark_quarry']!);
      h.press(AbilitySlot.spell);
      SelfAbilitySystem().step(h.world, currentTick: 1);
      expect(h.world.targetMark.target.single, target);
      final middleware = TargetMarkMiddleware();
      for (final source in [h.player, other]) {
        h.world.damageQueue.add(
          DamageRequest(
            target: target,
            amount100: 1000,
            source: source,
            sourceKind: DeathSourceKind.projectile,
          ),
        );
      }
      middleware.apply(h.world, h.world.damageQueue, 0, 2);
      middleware.apply(h.world, h.world.damageQueue, 1, 2);
      expect(h.world.damageQueue.amount100, [1250, 1000]);
      h.world.damageQueue.amount100[0] = 1000;
      middleware.apply(h.world, h.world.damageQueue, 0, 301);
      expect(h.world.damageQueue.amount100[0], 1000);
      h.world.destroyEntity(target);
      expect(h.world.targetMark.denseEntities, isEmpty);
      expect(h.world.createEntity(), target);
    },
  );
  test('mark without a hostile does not spend supplies', () {
    final h = _Harness();
    h.equip(bountyHunterAbilityDefs['bounty_hunter.mark_quarry']!);
    h.press(AbilitySlot.spell);
    expect(h.world.mana.mana[0], 10000);
    expect(h.world.activeAbility.abilityId[0], isNull);
  });
}

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

class _Harness {
  _Harness({
    this.tickHz = 60,
    ProjectileId weapon = ProjectileId.hunterPistol,
    bool Function(double, double, double, double)? aimPathClear,
  }) {
    player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 20,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(useGravity: false),
      collider: ColliderAabbDef(
        halfX: bountyHunterCatalog.colliderHalfX,
        halfY: bountyHunterCatalog.colliderHalfY,
        offsetX: bountyHunterCatalog.colliderOffsetX,
        offsetY: bountyHunterCatalog.colliderOffsetY,
      ),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
      equippedLoadout: _loadout,
    );
    _capsule(player);
    world.equippedLoadout.projectileSlotSpellId[0] = weapon;
    final character = bountyHunterCharacter.withProjectile(weapon);
    activation = AbilityActivationSystem(
      playerCharacter: character,
      playerCastOriginOffset: character.catalog.castOriginOffset,
      projectileAimPathClear: aimPathClear,
      tickHz: tickHz,
      inputBufferTicks: 8,
      abilities: AbilityCatalog.shared,
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    launch = ProjectileLaunchSystem(
      playerCharacter: character,
      projectiles: const ProjectileCatalog(),
      tickHz: tickHz,
    );
    movement = MovementTuningDerived.from(
      bountyHunterTuning.movement,
      tickHz: tickHz,
    );
  }
  final int tickHz;
  final world = EcsWorld();
  late final int player;
  late final AbilityActivationSystem activation;
  late final ProjectileLaunchSystem launch;
  late final MovementTuningDerived movement;
  void equip(AbilityDef ability) {
    final l = world.equippedLoadout;
    switch (ability.allowedSlots.single) {
      case AbilitySlot.primary:
        l.abilityPrimaryId[0] = ability.id;
      case AbilitySlot.secondary:
        l.abilitySecondaryId[0] = ability.id;
      case AbilitySlot.projectile:
        l.abilityProjectileId[0] = ability.id;
      case AbilitySlot.mobility:
        l.abilityMobilityId[0] = ability.id;
      case AbilitySlot.spell:
        l.abilitySpellId[0] = ability.id;
      case AbilitySlot.jump:
        l.abilityJumpId[0] = ability.id;
    }
  }

  void press(
    AbilitySlot slot, {
    double aimX = 1,
    double aimY = 0,
    int tick = 1,
  }) {
    final input = world.playerInput;
    input.hasAbilitySlotPressed[0] = true;
    input.lastAbilitySlotPressed[0] = slot;
    input.aimDirX[0] = aimX;
    input.aimDirY[0] = aimY;
    switch (slot) {
      case AbilitySlot.primary:
        input.strikePressed[0] = true;
      case AbilitySlot.secondary:
        input.secondaryPressed[0] = true;
      case AbilitySlot.projectile:
        input.projectilePressed[0] = true;
      case AbilitySlot.mobility:
        input.dashPressed[0] = true;
      case AbilitySlot.spell:
        input.spellPressed[0] = true;
      case AbilitySlot.jump:
        input.jumpPressed[0] = true;
    }
    activation.step(world, player: player, currentTick: tick);
  }

  int enemy(double x, double y, {Faction faction = Faction.enemy}) {
    final id = world.createEntity();
    world.transform.add(id, posX: x, posY: y, velX: 0, velY: 0);
    world.faction.add(id, FactionDef(faction: faction));
    world.statModifier.add(id);
    world.health.add(
      id,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.colliderAabb.add(id, const ColliderAabbDef(halfX: 6, halfY: 12));
    _capsule(id);
    return id;
  }

  void _capsule(int id) {
    final i = world.colliderAabb.indexOf(id);
    world.worldContactCapsule.add(
      id,
      WorldContactCapsuleDef.fromAabb(
        ColliderAabbDef(
          halfX: world.colliderAabb.halfX[i],
          halfY: world.colliderAabb.halfY[i],
        ),
      ),
    );
  }
}
