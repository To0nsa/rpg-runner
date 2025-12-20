import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/enemy_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/v0_flying_enemy_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_ground_enemy_tuning.dart';

import 'test_spawns.dart';

void main() {
  test('flying enemy steering is deterministic for the same seed', () {
    const seed = 12345;
    final worldA = EcsWorld(seed: seed);
    final worldB = EcsWorld(seed: seed);

    final playerA = worldA.createPlayer(
      posX: 300,
      posY: 120,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );
    final playerB = worldB.createPlayer(
      posX: 300,
      posY: 120,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final flyingEnemyA = spawnFlyingEnemy(worldA, posX: 100, posY: 120);
    final flyingEnemyB = spawnFlyingEnemy(worldB, posX: 100, posY: 120);

    final system = EnemySystem(
      flyingEnemyTuning: V0FlyingEnemyTuningDerived.from(
        const V0FlyingEnemyTuning(),
        tickHz: 60,
      ),
      groundEnemyTuning: V0GroundEnemyTuningDerived.from(
        const V0GroundEnemyTuning(),
        tickHz: 60,
      ),
    );

    const dtSeconds = 1.0 / 60.0;
    const groundTopY = 200.0;

    for (var i = 0; i < 5; i += 1) {
      system.stepSteering(
        worldA,
        player: playerA,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
      );
      system.stepSteering(
        worldB,
        player: playerB,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
      );

      final tiA = worldA.transform.indexOf(flyingEnemyA);
      final tiB = worldB.transform.indexOf(flyingEnemyB);
      expect(worldA.transform.velX[tiA], closeTo(worldB.transform.velX[tiB], 1e-9));
      expect(worldA.transform.velY[tiA], closeTo(worldB.transform.velY[tiB], 1e-9));
    }
  });
}
