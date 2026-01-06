import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/stores/restoration_item_store.dart';
import 'package:walkscape_runner/core/ecs/systems/restoration_item_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/restoration_item_tuning.dart';

void main() {
  test('RestorationItemSystem restores and despawns on overlap', () {
    final world = EcsWorld();
    final player = world.createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 4, hpMax: 10, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 0, staminaMax: 0, regenPerSecond: 0),
    );

    final item = world.createEntity();
    world.transform.add(item, posX: 100, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(
      item,
      const ColliderAabbDef(halfX: 6, halfY: 6),
    );
    world.restorationItem.add(
      item,
      const RestorationItemDef(stat: RestorationStat.health),
    );

    final system = RestorationItemSystem();
    system.step(
      world,
      player: player,
      cameraLeft: 0.0,
      tuning: const RestorationItemTuning(
        restorePercent: 0.30,
        despawnBehindCameraMargin: 100,
      ),
    );

    final hi = world.health.indexOf(player);
    expect(world.health.hp[hi], 7.0);
    expect(world.restorationItem.has(item), isFalse);
  });

  test('RestorationItemSystem despawns behind camera', () {
    final world = EcsWorld();
    final player = world.createPlayer(
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

    final item = world.createEntity();
    world.transform.add(item, posX: -500, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(
      item,
      const ColliderAabbDef(halfX: 6, halfY: 6),
    );
    world.restorationItem.add(
      item,
      const RestorationItemDef(stat: RestorationStat.mana),
    );

    final system = RestorationItemSystem();
    system.step(
      world,
      player: player,
      cameraLeft: 0.0,
      tuning: const RestorationItemTuning(despawnBehindCameraMargin: 100),
    );

    expect(world.restorationItem.has(item), isFalse);
  });
}
