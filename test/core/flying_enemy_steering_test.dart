import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/systems/flying_enemy_locomotion_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/flying_enemy_tuning.dart';

import 'test_spawns.dart';

void main() {
  test('flying enemy steering is deterministic for the same seed', () {
    const seed = 12345;
    final worldA = EcsWorld(seed: seed);
    final worldB = EcsWorld(seed: seed);

    final playerA = EntityFactory(worldA).createPlayer(
      posX: 300,
      posY: 120,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
    );
    final playerB = EntityFactory(worldB).createPlayer(
      posX: 300,
      posY: 120,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond100: 0),
    );

    final unocoDemonA = spawnUnocoDemon(worldA, posX: 100, posY: 120);
    final unocoDemonB = spawnUnocoDemon(worldB, posX: 100, posY: 120);

    final system = FlyingEnemyLocomotionSystem(
      unocoDemonTuning: UnocoDemonTuningDerived.from(
        const UnocoDemonTuning(),
        tickHz: 60,
      ),
    );

    const dtSeconds = 1.0 / 60.0;
    const groundTopY = 200.0;

    for (var i = 0; i < 5; i += 1) {
      system.step(
        worldA,
        player: playerA,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
        currentTick: i,
      );
      system.step(
        worldB,
        player: playerB,
        groundTopY: groundTopY,
        dtSeconds: dtSeconds,
        currentTick: i,
      );

      final tiA = worldA.transform.indexOf(unocoDemonA);
      final tiB = worldB.transform.indexOf(unocoDemonB);
      expect(worldA.transform.velX[tiA], closeTo(worldB.transform.velX[tiB], 1e-9));
      expect(worldA.transform.velY[tiA], closeTo(worldB.transform.velY[tiB], 1e-9));
    }
  });
}
