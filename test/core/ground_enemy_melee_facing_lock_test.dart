import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/enemies/enemy_id.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/enemies/melee_engagement_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/ground_enemy_locomotion_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/ground_enemy_tuning.dart';

void main() {
  test(
    'GroundEnemyLocomotionSystem locks facing to player during engage/strike/recover',
    () {
      for (final (state, expectedFacing) in <(MeleeEngagementState, Facing)>[
        (MeleeEngagementState.approach, Facing.left),
        (MeleeEngagementState.engage, Facing.right),
        (MeleeEngagementState.strike, Facing.right),
        (MeleeEngagementState.recover, Facing.right),
      ]) {
        final world = EcsWorld();

        final player = world.createEntity();
        world.transform.add(
          player,
          posX: 200.0,
          posY: 0.0,
          velX: 0.0,
          velY: 0.0,
        );

        final enemy = EntityFactory(world).createEnemy(
          enemyId: EnemyId.grojib,
          posX: 100.0,
          posY: 0.0,
          velX: 0.0,
          velY: 0.0,
          facing: Facing.right,
          body: const BodyDef(
            isKinematic: false,
            useGravity: true,
            gravityScale: 1.0,
            maxVelY: 9999,
          ),
          collider: const ColliderAabbDef(halfX: 8.0, halfY: 8.0),
          health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
          mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
          stamina: const StaminaDef(
            stamina: 0,
            staminaMax: 0,
            regenPerSecond100: 0,
          ),
        );

        world.collision.grounded[world.collision.indexOf(enemy)] = true;

        final meleeIndex = world.meleeEngagement.indexOf(enemy);
        world.meleeEngagement.state[meleeIndex] = state;

        final intentIndex = world.navIntent.indexOf(enemy);
        world.navIntent.hasPlan[intentIndex] = false;
        world.navIntent.desiredX[intentIndex] = 999.0; // ignored when no plan
        world.navIntent.jumpNow[intentIndex] = false;
        world.navIntent.commitMoveDirX[intentIndex] = 0;
        world.navIntent.hasSafeSurface[intentIndex] = false;

        final engagementIndex = world.engagementIntent.indexOf(enemy);
        world.engagementIntent.desiredTargetX[engagementIndex] = 0.0; // behind
        world.engagementIntent.arrivalSlowRadiusX[engagementIndex] = 0.0;
        world.engagementIntent.stateSpeedMul[engagementIndex] = 1.0;
        world.engagementIntent.speedScale[engagementIndex] = 1.0;

        final locomotionSystem = GroundEnemyLocomotionSystem(
          groundEnemyTuning: GroundEnemyTuningDerived.from(
            const GroundEnemyTuning(
              locomotion: GroundEnemyLocomotionTuning(
                speedX: 200.0,
                accelX: 600.0,
                decelX: 600.0,
                stopDistanceX: 1.0,
              ),
            ),
            tickHz: 60,
          ),
        );

        locomotionSystem.step(
          world,
          player: player,
          dtSeconds: 1.0 / 60.0,
          currentTick: 0,
        );

        final enemyTi = world.transform.indexOf(enemy);
        expect(world.transform.velX[enemyTi], lessThan(0.0));

        final enemyIndex = world.enemy.indexOf(enemy);
        expect(world.enemy.facing[enemyIndex], expectedFacing);
      }
    },
  );
}
