import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/faction_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/hitbox_follow_owner_system.dart';
import 'package:rpg_runner/core/ecs/systems/lifetime_system.dart';
import 'package:rpg_runner/core/ecs/systems/melee_strike_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test('melee hitbox damages only once per swing', () {
    final world = EcsWorld();
    final activation = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 0,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
    final meleeStrike = MeleeStrikeSystem();
    final follow = HitboxFollowOwnerSystem();
    final hitboxDamage = HitboxDamageSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);
    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    );
    final lifetime = LifetimeSystem();

    final player = EntityFactory(world).createPlayer(
      posX: 100,
      posY: 100,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
    );

    // This test expects the primary button to execute a melee strike (not parry).
    final li = world.equippedLoadout.indexOf(player);
    world.equippedLoadout.abilityPrimaryId[li] = 'eloise.bloodletter_slash';

    final enemy = world.createEntity();
    world.transform.add(enemy, posX: 110, posY: 100, velX: 0, velY: 0);
    world.colliderAabb.add(enemy, const ColliderAabbDef(halfX: 8, halfY: 8));
    world.health.add(
      enemy,
      const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
    );
    world.faction.add(enemy, const FactionDef(faction: Faction.enemy));

    final playerInputIndex = world.playerInput.indexOf(player);
    world.playerInput.strikePressed[playerInputIndex] = true;

    // Windup for eloise.sword_strike is 8 ticks at 60Hz.
    for (var tick = 1; tick <= 9; tick += 1) {
      activation.step(world, player: player, currentTick: tick);
      meleeStrike.step(world, currentTick: tick);
      follow.step(world);
      broadphase.rebuild(world);
      hitboxDamage.step(world, broadphase, currentTick: tick);
      damage.step(world, currentTick: tick);
      lifetime.step(world);
      // Clear the one-shot press after the first tick.
      if (tick == 1) {
        world.playerInput.strikePressed[playerInputIndex] = false;
      }
    }

    // Default starter loadout uses Plainsteel (+1% power); 1500 base becomes 1515.
    expect(world.health.hp[world.health.indexOf(enemy)], equals(8485));

    // Next tick: still overlapping, but should not re-hit the same target.
    activation.step(world, player: player, currentTick: 10);
    meleeStrike.step(world, currentTick: 10);
    follow.step(world);
    broadphase.rebuild(world);
    hitboxDamage.step(world, broadphase, currentTick: 10);
    damage.step(world, currentTick: 10);
    lifetime.step(world);

    expect(world.health.hp[world.health.indexOf(enemy)], equals(8485));
  });
}
