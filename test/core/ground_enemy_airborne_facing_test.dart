import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';

void main() {
  test('GroundEnemyLocomotionSystem does not flip facing mid-air from desiredX', () {
    final world = EcsWorld();

    final player = world.createEntity();
    world.transform.add(
      player,
      posX: 0.0,
      posY: 0.0,
      velX: 0.0,
      velY: 0.0,
    );

    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.groundEnemy,
      posX: 100.0,
      posY: 0.0,
      velX: 50.0,
      velY: 0.0,
      facing: Facing.right,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        gravityScale: 1.0,
        maxVelY: 9999,
      ),
      collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
      health: const HealthDef(hp: 10, hpMax: 10, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    world.collision.grounded[world.collision.indexOf(enemy)] = false;

    final intentIndex = world.navIntent.indexOf(enemy);
    world.navIntent.hasPlan[intentIndex] = true;
    world.navIntent.desiredX[intentIndex] = 0.0; // behind the enemy
    world.navIntent.jumpNow[intentIndex] = false;
    world.navIntent.commitMoveDirX[intentIndex] = 0;

    final locomotionSystem = GroundEnemyLocomotionSystem(
      groundEnemyTuning: GroundEnemyTuningDerived.from(
        const GroundEnemyTuning(
          locomotion: GroundEnemyLocomotionTuning(
            speedX: 200.0,
            accelX: 10.0,
            decelX: 10.0,
            stopDistanceX: 1.0,
          ),
        ),
        tickHz: 60,
      ),
    );

    locomotionSystem.step(world, player: player, dtSeconds: 1.0 / 60.0);

    final enemyIndex = world.enemy.indexOf(enemy);
    expect(world.enemy.facing[enemyIndex], Facing.right);
  });
}

