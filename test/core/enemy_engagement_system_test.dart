import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/enemy_engagement_system.dart';
import 'package:runner_core/ecs/stores/enemies/melee_engagement_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/ground_enemy_tuning.dart';

void main() {
  test('hashash emits chase engagement intent while approaching', () {
    final world = EcsWorld(seed: 7);
    final factory = EntityFactory(world);
    final enemyCatalog = EnemyCatalog();
    final system = EnemyEngagementSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(),
        tickHz: 60,
      ),
      enemyCatalog: enemyCatalog,
    );

    final player = world.createEntity();
    world.transform.add(player, posX: 120.0, posY: 0.0, velX: 0.0, velY: 0.0);

    final archetype = enemyCatalog.get(EnemyId.hashash);
    final hashash = factory.createEnemy(
      enemyId: EnemyId.hashash,
      posX: 0.0,
      posY: 0.0,
      velX: 0.0,
      velY: 0.0,
      facing: Facing.left,
      body: BodyDef(
        isKinematic: archetype.body.isKinematic,
        useGravity: archetype.body.useGravity,
        ignoreCeilings: archetype.body.ignoreCeilings,
        gravityScale: archetype.body.gravityScale,
        sideMask: archetype.body.sideMask,
      ),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    final navIndex = world.navIntent.indexOf(hashash);
    world.navIntent.navTargetX[navIndex] = 120.0;
    world.navIntent.desiredX[navIndex] = 120.0;

    system.step(world, player: player, currentTick: 1);

    final chaseIndex = world.groundEnemyChaseOffset.indexOf(hashash);
    final engagementIndex = world.engagementIntent.indexOf(hashash);
    final expectedTargetX =
        world.navIntent.navTargetX[navIndex] +
        world.groundEnemyChaseOffset.chaseOffsetX[chaseIndex];

    expect(
      world.engagementIntent.desiredTargetX[engagementIndex],
      closeTo(expectedTargetX, 1e-6),
    );
    expect(
      world.engagementIntent.speedScale[engagementIndex],
      closeTo(world.groundEnemyChaseOffset.chaseSpeedScale[chaseIndex], 1e-6),
    );
    final meleeIndex = world.meleeEngagement.indexOf(hashash);
    expect(
      world.meleeEngagement.state[meleeIndex],
      MeleeEngagementState.approach,
    );
    expect(world.meleeEngagement.strikeAbilityId[meleeIndex], isNull);
  });
}
