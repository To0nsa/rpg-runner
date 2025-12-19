import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/core/combat/faction.dart';
import 'package:walkscape_runner/core/ecs/stores/body_store.dart';
import 'package:walkscape_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:walkscape_runner/core/ecs/stores/faction_store.dart';
import 'package:walkscape_runner/core/ecs/stores/health_store.dart';
import 'package:walkscape_runner/core/ecs/stores/mana_store.dart';
import 'package:walkscape_runner/core/ecs/stores/stamina_store.dart';
import 'package:walkscape_runner/core/ecs/systems/damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:walkscape_runner/core/ecs/systems/lifetime_system.dart';
import 'package:walkscape_runner/core/ecs/systems/player_melee_system.dart';
import 'package:walkscape_runner/core/ecs/world.dart';
import 'package:walkscape_runner/core/snapshots/enums.dart';
import 'package:walkscape_runner/core/tuning/v0_ability_tuning.dart';
import 'package:walkscape_runner/core/tuning/v0_movement_tuning.dart';

void main() {
  test('melee hitbox damages only once per swing', () {
    final movement = V0MovementTuningDerived.from(
      const V0MovementTuning(playerRadius: 8),
      tickHz: 60,
    );
    final abilities = V0AbilityTuningDerived.from(
      const V0AbilityTuning(
        meleeCooldownSeconds: 0.30,
        meleeActiveSeconds: 0.10,
        meleeStaminaCost: 15,
        meleeDamage: 25,
        meleeHitboxSizeX: 32,
        meleeHitboxSizeY: 16,
      ),
      tickHz: 60,
    );

    final world = EcsWorld();
    final melee = PlayerMeleeSystem(abilities: abilities, movement: movement);
    final hitboxDamage = HitboxDamageSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0);
    final lifetime = LifetimeSystem();

    final player = world.createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond: 0),
      stamina: const StaminaDef(stamina: 100, staminaMax: 100, regenPerSecond: 0),
    );

    final enemy = world.createEntity();
    world.transform.add(enemy, posX: 120, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(enemy, const ColliderAabbDef(halfX: 8, halfY: 8));
    world.health.add(enemy, const HealthDef(hp: 100, hpMax: 100, regenPerSecond: 0));
    world.faction.add(enemy, const FactionDef(faction: Faction.enemy));

    final playerInputIndex = world.playerInput.indexOf(player);
    world.playerInput.attackPressed[playerInputIndex] = true;

    melee.step(world, player: player);
    hitboxDamage.step(world, damage.queue);
    damage.step(world);
    lifetime.step(world);

    expect(world.health.hp[world.health.indexOf(enemy)], closeTo(75.0, 1e-9));

    // Next tick: still overlapping, but should not re-hit the same target.
    world.playerInput.attackPressed[playerInputIndex] = false;
    melee.step(world, player: player);
    hitboxDamage.step(world, damage.queue);
    damage.step(world);
    lifetime.step(world);

    expect(world.health.hp[world.health.indexOf(enemy)], closeTo(75.0, 1e-9));
  });
}
