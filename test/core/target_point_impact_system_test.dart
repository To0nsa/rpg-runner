import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/spatial/broadphase_grid.dart';
import 'package:runner_core/ecs/spatial/grid_index_2d.dart';
import 'package:runner_core/ecs/systems/damage_system.dart';
import 'package:runner_core/ecs/systems/enemy_cast_system.dart';
import 'package:runner_core/ecs/systems/hitbox_damage_system.dart';
import 'package:runner_core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:runner_core/ecs/systems/target_point_impact_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/events/game_event.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';

void main() {
  test(
    'derf cast writes target-point intent, impact remains world-anchored, and damage source is spellImpact',
    () {
      final world = EcsWorld();
      final factory = EntityFactory(world);
      const enemyCatalog = EnemyCatalog();
      final derfArchetype = enemyCatalog.get(EnemyId.derf);

      final player = factory.createPlayer(
        posX: 300.0,
        posY: 120.0,
        velX: 0.0,
        velY: 0.0,
        facing: Facing.right,
        grounded: true,
        body: derfArchetype.body,
        collider: derfArchetype.collider,
        health: derfArchetype.health,
        mana: derfArchetype.mana,
        stamina: derfArchetype.stamina,
      );

      final derf = factory.createEnemy(
        enemyId: EnemyId.derf,
        posX: 140.0,
        posY: 120.0,
        velX: 0.0,
        velY: 0.0,
        facing: Facing.left,
        body: derfArchetype.body,
        collider: derfArchetype.collider,
        health: derfArchetype.health,
        mana: derfArchetype.mana,
        stamina: derfArchetype.stamina,
      );
      world.cooldown.setTicksLeft(derf, 2, 0);

      final castSystem = EnemyCastSystem(
        unocoDemonTuning: UnocoDemonTuningDerived.from(
          const UnocoDemonTuning(),
          tickHz: 60,
        ),
        enemyCatalog: enemyCatalog,
        projectiles: const ProjectileCatalog(),
      );

      const commitTick = 10;
      castSystem.step(world, player: player, currentTick: commitTick);

      final intentIndex = world.targetPointIntent.indexOf(derf);
      expect(
        world.targetPointIntent.abilityId[intentIndex],
        equals('derf.fire_explosion'),
      );
      expect(world.targetPointIntent.sourceKind[intentIndex], DeathSourceKind.spellImpact);

      final executeTick = world.targetPointIntent.tick[intentIndex];
      final targetX = world.targetPointIntent.targetX[intentIndex];
      final targetY = world.targetPointIntent.targetY[intentIndex];
      expect(executeTick, greaterThan(commitTick));

      final playerColliderIndex = world.colliderAabb.indexOf(player);
      final playerTransformIndex = world.transform.indexOf(player);
      world.transform.posX[playerTransformIndex] =
          targetX - world.colliderAabb.offsetX[playerColliderIndex];
      world.transform.posY[playerTransformIndex] =
          targetY - world.colliderAabb.offsetY[playerColliderIndex];

      final impactEvents = <SpellImpactEvent>[];
      final impactSystem = TargetPointImpactSystem(
        queueImpactEvent: impactEvents.add,
      );
      impactSystem.step(world, currentTick: executeTick);

      expect(impactEvents.length, 1);
      expect(impactEvents.single.impactId, isNotNull);
      expect(world.hitbox.denseEntities.length, 1);
      final hitbox = world.hitbox.denseEntities.single;

      final hitboxTransformIndex = world.transform.indexOf(hitbox);
      final anchoredX = world.transform.posX[hitboxTransformIndex];
      final anchoredY = world.transform.posY[hitboxTransformIndex];

      final derfTransformIndex = world.transform.indexOf(derf);
      world.transform.posX[derfTransformIndex] += 500.0;
      world.transform.posY[derfTransformIndex] += 120.0;
      HitboxFollowOwnerSystem().step(world);

      expect(world.transform.posX[hitboxTransformIndex], closeTo(anchoredX, 1e-9));
      expect(world.transform.posY[hitboxTransformIndex], closeTo(anchoredY, 1e-9));

      final broadphase = BroadphaseGrid(index: GridIndex2D(cellSize: 64.0));
      broadphase.rebuild(world);
      HitboxDamageSystem(enemyCatalog: enemyCatalog).step(
        world,
        broadphase,
        currentTick: executeTick,
      );
      DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 123).step(
        world,
        currentTick: executeTick,
      );

      final lastDamageIndex = world.lastDamage.indexOf(player);
      expect(world.lastDamage.kind[lastDamageIndex], DeathSourceKind.spellImpact);
    },
  );
}
