import 'dart:math' as math;

import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/combat/ai_target_policy.dart';
import 'package:runner_core/combat/control_lock.dart';
import 'package:runner_core/combat/damage_credit.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/ai_target_system.dart';
import 'package:runner_core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:runner_core/ecs/systems/npc_ai_system.dart';
import 'package:runner_core/ecs/systems/npc_combat_lifecycle.dart';
import 'package:runner_core/ecs/systems/projectile_launch_system.dart';
import 'package:runner_core/ecs/systems/projectile_hit_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';
import 'package:test/test.dart';

void main() {
  for (final id in [NpcId.huntress, NpcId.huntress2]) {
    for (final direction in [-1, 1]) {
      test(
        '${id.name} pays once and launches an allied physical projectile in direction $direction',
        () {
          final h = _Harness(id, direction: direction);
          final archetype = const NpcCatalog().get(id);
          final ability = AbilityCatalog.shared.resolve(
            archetype.attackAbilityId,
          )!;
          h.ai.step(h.world, currentTick: 10, dtSeconds: 1 / 60);
          h.ai.step(h.world, currentTick: 10, dtSeconds: 1 / 60);
          final intents = h.world.projectileIntent;
          final ii = intents.indexOf(h.npc);
          final launchTick = 10 + ability.windupTicks;
          expect(intents.tick[ii], launchTick);
          expect(
            h.world.stamina.stamina[h.world.stamina.indexOf(h.npc)],
            4000 - ability.defaultCost.staminaCost100,
          );
          h.launch.step(h.world, currentTick: launchTick - 1);
          expect(h.world.projectile.denseEntities, isEmpty);
          h.launch.step(h.world, currentTick: launchTick);
          h.launch.step(h.world, currentTick: launchTick);
          final projectile = h.world.projectile.denseEntities.single;
          final pi = h.world.projectile.indexOf(projectile);
          expect(h.world.projectile.faction[pi], Faction.player);
          expect(h.world.projectile.credit[pi], DamageCredit.none);
          expect(h.world.projectile.dirX[pi].sign, direction);
          expect(
            playerEquippableProjectileIds,
            isNot(contains(h.world.projectile.projectileId[pi])),
          );
          final pt = h.world.transform.indexOf(projectile);
          final length = math.sqrt(
            intents.dirX[ii] * intents.dirX[ii] +
                intents.dirY[ii] * intents.dirY[ii],
          );
          expect(
            h.world.transform.posY[pt],
            closeTo(
              100 +
                  archetype.castOriginOffsetY +
                  intents.dirY[ii] / length * archetype.castOriginOffset!,
              1e-9,
            ),
          );
          // Safe survivors stop committing, while detached attacks keep their payload.
          protectNpc(h.world, h.npc);
          expect(h.world.projectile.has(projectile), isTrue);
          final et = h.world.transform.indexOf(h.enemy);
          h.world.transform.posX[pt] = h.world.transform.posX[et];
          h.world.transform.posY[pt] = h.world.transform.posY[et];
          final grid = BroadphaseGrid(index: GridIndex2D(cellSize: 64))
            ..rebuild(h.world);
          ProjectileHitSystem().step(
            h.world,
            grid,
            currentTick: launchTick + 1,
          );
          expect(h.world.damageQueue.target.single, h.enemy);
          expect(h.world.damageQueue.amount100.single, ability.baseDamage);
          expect(h.world.damageQueue.credit.single, DamageCredit.none);
        },
      );
    }
    for (final reason in [
      'stun',
      'cast lock',
      'stamina',
      'dead',
      'protected',
    ]) {
      test('${id.name} rejects $reason before spending resources', () {
        final h = _Harness(id);
        switch (reason) {
          case 'stun':
            h.world.controlLock.addLock(h.npc, LockFlag.stun, 100, 0);
          case 'cast lock':
            h.world.controlLock.addLock(h.npc, LockFlag.cast, 100, 0);
          case 'stamina':
            h.world.stamina.stamina[h.world.stamina.indexOf(h.npc)] = 0;
          case 'dead':
            h.world.health.hp[h.world.health.indexOf(h.npc)] = 0;
          case 'protected':
            protectNpc(h.world, h.npc);
        }
        final before = h.world.stamina.stamina[h.world.stamina.indexOf(h.npc)];
        h.ai.step(h.world, currentTick: 10, dtSeconds: 1 / 60);
        expect(
          h.world.projectileIntent.tick[h.world.projectileIntent.indexOf(
            h.npc,
          )],
          -1,
        );
        expect(h.world.stamina.stamina[h.world.stamina.indexOf(h.npc)], before);
      });
    }
    test(
      '${id.name} rescue cancels a committed projectile before its release',
      () {
        final h = _Harness(id);
        h.ai.step(h.world, currentTick: 10, dtSeconds: 1 / 60);
        final scheduled = h
            .world
            .projectileIntent
            .tick[h.world.projectileIntent.indexOf(h.npc)];
        expect(scheduled, greaterThan(10));
        protectNpc(h.world, h.npc);
        h.launch.step(h.world, currentTick: scheduled);
        expect(h.world.projectile.denseEntities, isEmpty);
      },
    );
  }
}

class _Harness {
  _Harness(NpcId id, {int direction = 1}) {
    npc = EntityFactory(world).createNpc(
      npcId: id,
      posX: 300,
      posY: 100,
      chunkStartX: 0,
      chunkEndX: 600,
    );
    final archetype = const EnemyCatalog().get(EnemyId.grojib);
    enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.grojib,
      posX: 300 + direction * 150,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: archetype.body,
      collider: archetype.collider,
      health: archetype.health,
      mana: archetype.mana,
      stamina: archetype.stamina,
    );
    world.worldContactCapsule.add(
      npc,
      const NpcCatalog().terrainContactProfile(id).capsule,
    );
    world.worldContactCapsule.add(
      enemy,
      const EnemyCatalog().terrainContactProfile(EnemyId.grojib).capsule,
    );
    world.collision.grounded[world.collision.indexOf(npc)] = true;
    world.aiTarget.configure(
      npc,
      targetPolicy: AiTargetPolicy.nearestOpponent,
      candidates: [enemy],
      playerFallback: false,
    );
    AiTargetSystem().step(world, player: -1);
  }
  final world = EcsWorld();
  late final int npc, enemy;
  final ai = NpcAiSystem(
    tickHz: 60,
    locomotion: GroundEnemyLocomotionSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(),
        tickHz: 60,
      ),
    ),
  );
  final launch = ProjectileLaunchSystem(
    projectiles: const ProjectileCatalog(),
    tickHz: 60,
  );
}
