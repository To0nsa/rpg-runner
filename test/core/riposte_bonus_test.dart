import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/combat/status/status.dart';
import 'package:rpg_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/faction_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/hitbox_store.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';

void main() {
  test('Riposte bonus applies only when a melee hit lands (and is then consumed)', () {
    final world = EcsWorld();

    final attacker = world.createEntity();
    world.health.add(
      attacker,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.faction.add(attacker, const FactionDef(faction: Faction.player));
    world.transform.add(attacker, posX: 0, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(attacker, const ColliderAabbDef(halfX: 1, halfY: 1));

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.faction.add(target, const FactionDef(faction: Faction.enemy));
    world.transform.add(target, posX: 0, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(target, const ColliderAabbDef(halfX: 1, halfY: 1));

    world.riposte.grant(attacker, expiresAtTick: 60, bonusBp: 10000);

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: 0, posY: 0, velX: 0, velY: 0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: attacker,
        faction: Faction.player,
        damage100: 1000,
        damageType: DamageType.physical,
        statusProfileId: StatusProfileId.none,
        halfX: 1.0,
        halfY: 1.0,
        offsetX: 0.0,
        offsetY: 0.0,
        dirX: 1.0,
        dirY: 0.0,
      ),
    );
    world.hitOnce.add(hitbox);

    final broadphase = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
    broadphase.rebuild(world);

    HitboxDamageSystem().step(world, broadphase, currentTick: 0);

    expect(world.damageQueue.length, equals(1));
    expect(world.damageQueue.target.single, equals(target));
    expect(world.damageQueue.amount100.single, equals(2000));
    expect(world.riposte.has(attacker), isFalse);
  });

  test('Riposte bonus is not consumed on misses', () {
    final world = EcsWorld();

    final attacker = world.createEntity();
    world.health.add(
      attacker,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.faction.add(attacker, const FactionDef(faction: Faction.player));
    world.transform.add(attacker, posX: 0, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(attacker, const ColliderAabbDef(halfX: 1, halfY: 1));

    final target = world.createEntity();
    world.health.add(
      target,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.faction.add(target, const FactionDef(faction: Faction.enemy));
    world.transform.add(target, posX: 1000, posY: 0, velX: 0, velY: 0);
    world.colliderAabb.add(target, const ColliderAabbDef(halfX: 1, halfY: 1));

    world.riposte.grant(attacker, expiresAtTick: 60, bonusBp: 10000);

    final hitbox = world.createEntity();
    world.transform.add(hitbox, posX: 0, posY: 0, velX: 0, velY: 0);
    world.hitbox.add(
      hitbox,
      HitboxDef(
        owner: attacker,
        faction: Faction.player,
        damage100: 1000,
        damageType: DamageType.physical,
        statusProfileId: StatusProfileId.none,
        halfX: 1.0,
        halfY: 1.0,
        offsetX: 0.0,
        offsetY: 0.0,
        dirX: 1.0,
        dirY: 0.0,
      ),
    );
    world.hitOnce.add(hitbox);

    final broadphase = BroadphaseGrid(index: GridIndex2D(cellSize: 64));
    broadphase.rebuild(world);

    HitboxDamageSystem().step(world, broadphase, currentTick: 0);

    expect(world.damageQueue.length, equals(0));
    expect(world.riposte.has(attacker), isTrue);
  });
}

