import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/snapshots/enums.dart';

void main() {
  test('createEnemy initializes LastDamageStore by default', () {
    final world = EcsWorld();
    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.unocoDemon,
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    expect(world.lastDamage.has(enemy), isTrue);
    expect(world.lastDamage.tick[world.lastDamage.indexOf(enemy)], equals(-1));
  });

  test('createEnemy hashash wires the ground-enemy component stack', () {
    final world = EcsWorld(seed: 42);
    final enemy = EntityFactory(world).createEnemy(
      enemyId: EnemyId.hashash,
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.left,
      body: const BodyDef(
        isKinematic: false,
        useGravity: true,
        ignoreCeilings: true,
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

    expect(world.surfaceNav.has(enemy), isTrue);
    expect(world.groundEnemyChaseOffset.has(enemy), isTrue);
    expect(world.navIntent.has(enemy), isTrue);
    expect(world.engagementIntent.has(enemy), isTrue);
    expect(world.meleeEngagement.has(enemy), isTrue);
    expect(world.meleeCombo.has(enemy), isTrue);
    expect(world.hashashTeleport.has(enemy), isTrue);
    expect(world.flyingEnemySteering.has(enemy), isFalse);
    expect(world.flyingEnemyCombatMode.has(enemy), isFalse);
  });
}
