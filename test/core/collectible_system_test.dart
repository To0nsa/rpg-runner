import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collectible_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/collectible_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/collectible_tuning.dart';
import 'package:walkscape_runner/core/ecs/entity_factory.dart';

void main() {
  test('CollectibleSystem collects overlapping pickups', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10, hpMax: 10, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final collectible = world.createEntity();
    world.transform.add(collectible, posX: 100, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(
      collectible,
      const ColliderAabbDef(halfX: 6, halfY: 6),
    );
    world.collectible.add(collectible, const CollectibleDef(value: 3));

    final system = CollectibleSystem();
    var collectedValue = 0;
    system.step(
      world,
      player: player,
      cameraLeft: 0.0,
      tuning: const CollectibleTuning(despawnBehindCameraMargin: 100),
      onCollected: (value) => collectedValue += value,
    );

    expect(collectedValue, 3);
    expect(world.collectible.has(collectible), isFalse);
  });

  test('CollectibleSystem despawns behind camera', () {
    final world = EcsWorld();
    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10, hpMax: 10, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final collectible = world.createEntity();
    world.transform.add(collectible, posX: -500, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(
      collectible,
      const ColliderAabbDef(halfX: 6, halfY: 6),
    );
    world.collectible.add(collectible, const CollectibleDef(value: 1));

    final system = CollectibleSystem();
    system.step(
      world,
      player: player,
      cameraLeft: 0.0,
      tuning: const CollectibleTuning(despawnBehindCameraMargin: 100),
      onCollected: (_) {},
    );

    expect(world.collectible.has(collectible), isFalse);
  });
}
