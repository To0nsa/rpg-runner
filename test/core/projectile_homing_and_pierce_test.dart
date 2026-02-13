import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;

import 'package:rpg_runner/core/abilities/ability_catalog.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/accessories/accessory_catalog.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';
import 'package:rpg_runner/core/combat/faction.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/stores/body_store.dart';
import 'package:rpg_runner/core/ecs/stores/collider_aabb_store.dart';
import 'package:rpg_runner/core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:rpg_runner/core/ecs/stores/faction_store.dart';
import 'package:rpg_runner/core/ecs/stores/health_store.dart';
import 'package:rpg_runner/core/ecs/stores/mana_store.dart';
import 'package:rpg_runner/core/ecs/stores/stamina_store.dart';
import 'package:rpg_runner/core/ecs/spatial/broadphase_grid.dart';
import 'package:rpg_runner/core/ecs/spatial/grid_index_2d.dart';
import 'package:rpg_runner/core/ecs/systems/ability_activation_system.dart';
import 'package:rpg_runner/core/ecs/systems/damage_system.dart';
import 'package:rpg_runner/core/ecs/systems/projectile_hit_system.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/projectiles/spawn_projectile_item.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/spellBook/spell_book_catalog.dart';
import 'package:rpg_runner/core/tuning/spatial_grid_tuning.dart';
import 'package:rpg_runner/core/weapons/weapon_catalog.dart';

void main() {
  test('homing projectile intent aims at nearest hostile target', () {
    final world = EcsWorld();
    final system = AbilityActivationSystem(
      tickHz: 60,
      inputBufferTicks: 10,
      abilities: const AbilityCatalog(),
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );

    final player = world.createEntity();
    world.transform.add(player, posX: 100, posY: 100, velX: 0, velY: 0);
    world.faction.add(player, const FactionDef(faction: Faction.player));
    world.health.add(
      player,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );
    world.playerInput.add(player);
    world.movement.add(player, facing: Facing.right);
    world.abilityInputBuffer.add(player);
    world.activeAbility.add(player);
    world.cooldown.add(player);
    world.mana.add(
      player,
      const ManaDef(mana: 5000, manaMax: 5000, regenPerSecond100: 0),
    );
    world.stamina.add(
      player,
      const StaminaDef(stamina: 5000, staminaMax: 5000, regenPerSecond100: 0),
    );
    world.projectileIntent.add(player);
    world.equippedLoadout.add(
      player,
      const EquippedLoadoutDef(
        abilityProjectileId: 'eloise.auto_aim_shot',
        projectileSlotSpellId: ProjectileId.iceBolt,
      ),
    );

    final enemyNear = world.createEntity();
    world.transform.add(enemyNear, posX: 160, posY: 100, velX: 0, velY: 0);
    world.faction.add(enemyNear, const FactionDef(faction: Faction.enemy));
    world.health.add(
      enemyNear,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );

    final enemyFar = world.createEntity();
    world.transform.add(enemyFar, posX: 320, posY: 100, velX: 0, velY: 0);
    world.faction.add(enemyFar, const FactionDef(faction: Faction.enemy));
    world.health.add(
      enemyFar,
      const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
    );

    final inputIndex = world.playerInput.indexOf(player);
    world.playerInput.projectilePressed[inputIndex] = true;

    system.step(world, player: player, currentTick: 1);

    final intentIndex = world.projectileIntent.indexOf(player);
    expect(world.projectileIntent.tick[intentIndex], greaterThanOrEqualTo(1));
    expect(world.projectileIntent.dirX[intentIndex], closeTo(1.0, 1e-9));
    expect(world.projectileIntent.dirY[intentIndex].abs(), lessThan(1e-9));
  });

  test(
    'charged shot uses tiered damage/speed/effects from charge hold ticks',
    () {
      ({
        int damage100,
        int critBp,
        int speedScaleBp,
        bool pierce,
        int maxPierce,
      })
      resolveIntent(int chargeTicks) {
        final world = EcsWorld();
        final system = AbilityActivationSystem(
          tickHz: 60,
          inputBufferTicks: 10,
          abilities: const AbilityCatalog(),
          weapons: const WeaponCatalog(),
          projectiles: const ProjectileCatalog(),
          spellBooks: const SpellBookCatalog(),
          accessories: const AccessoryCatalog(),
        );

        final player = world.createEntity();
        world.transform.add(player, posX: 100, posY: 100, velX: 0, velY: 0);
        world.faction.add(player, const FactionDef(faction: Faction.player));
        world.health.add(
          player,
          const HealthDef(hp: 1000, hpMax: 1000, regenPerSecond100: 0),
        );
        world.playerInput.add(player);
        world.movement.add(player, facing: Facing.right);
        world.abilityInputBuffer.add(player);
        world.abilityCharge.add(player);
        world.activeAbility.add(player);
        world.cooldown.add(player);
        world.mana.add(
          player,
          const ManaDef(mana: 5000, manaMax: 5000, regenPerSecond100: 0),
        );
        world.stamina.add(
          player,
          const StaminaDef(
            stamina: 5000,
            staminaMax: 5000,
            regenPerSecond100: 0,
          ),
        );
        world.projectileIntent.add(player);
        world.equippedLoadout.add(
          player,
          const EquippedLoadoutDef(
            abilityProjectileId: 'eloise.charged_shot',
            projectileSlotSpellId: null,
            projectileId: ProjectileId.throwingKnife,
          ),
        );

        final inputIndex = world.playerInput.indexOf(player);
        world.playerInput.projectilePressed[inputIndex] = true;
        final chargeIndex = world.abilityCharge.indexOf(player);
        final slotOffset = world.abilityCharge.slotOffsetForDenseIndex(
          chargeIndex,
          AbilitySlot.projectile,
        );
        world.abilityCharge.releasedHoldTicksBySlot[slotOffset] = chargeTicks;
        world.abilityCharge.releasedTickBySlot[slotOffset] = 1;

        system.step(world, player: player, currentTick: 1);

        final ii = world.projectileIntent.indexOf(player);
        return (
          damage100: world.projectileIntent.damage100[ii],
          critBp: world.projectileIntent.critChanceBp[ii],
          speedScaleBp: world.projectileIntent.speedScaleBp[ii],
          pierce: world.projectileIntent.pierce[ii],
          maxPierce: world.projectileIntent.maxPierceHits[ii],
        );
      }

      final tap = resolveIntent(0);
      final ability = AbilityCatalog.shared.resolve('eloise.charged_shot')!;
      final hitDelivery = ability.hitDelivery as ProjectileHitDelivery;
      final baseMaxPierce = !hitDelivery.pierce
          ? 1
          : (hitDelivery.chainCount > 0 ? hitDelivery.chainCount : 2);
      final halfTierTicks = math.max(1, ability.windupTicks ~/ 2);
      final fullTierTicks = math.max(halfTierTicks + 1, ability.windupTicks);
      final half = resolveIntent(halfTierTicks);
      final full = resolveIntent(fullTierTicks);

      expect(tap.damage100, (ability.baseDamage * 8200) ~/ 10000);
      expect(tap.critBp, 0);
      expect(tap.speedScaleBp, 9000);
      expect(tap.pierce, hitDelivery.pierce);
      expect(tap.maxPierce, baseMaxPierce);

      expect(half.damage100, (ability.baseDamage * 10000) ~/ 10000);
      expect(half.critBp, 500);
      expect(half.speedScaleBp, 10500);
      expect(half.pierce, hitDelivery.pierce);
      expect(half.maxPierce, baseMaxPierce);

      expect(full.damage100, (ability.baseDamage * 12250) ~/ 10000);
      expect(full.critBp, 1000);
      expect(full.speedScaleBp, 12000);
      expect(full.pierce, isTrue);
      expect(full.maxPierce, math.max(baseMaxPierce, 2));
    },
  );

  test('piercing projectile damages multiple targets in one pass', () {
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
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 0,
        staminaMax: 0,
        regenPerSecond100: 0,
      ),
    );

    int spawnEnemy(double x) {
      final enemy = world.createEntity();
      world.transform.add(enemy, posX: x, posY: 100, velX: 0, velY: 0);
      world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
      world.colliderAabb.add(enemy, const ColliderAabbDef(halfX: 8, halfY: 8));
      world.health.add(
        enemy,
        const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      );
      return enemy;
    }

    final enemyA = spawnEnemy(140);
    final enemyB = spawnEnemy(152);

    final projectile = spawnProjectileFromCaster(
      world,
      tickHz: 60,
      projectileId: ProjectileId.iceBolt,
      projectile: const ProjectileCatalog().get(ProjectileId.iceBolt),
      faction: Faction.player,
      owner: player,
      casterX: 146,
      casterY: 100,
      originOffset: 0,
      dirX: 1,
      dirY: 0,
      fallbackDirX: 1,
      fallbackDirY: 0,
      damage100: 1200,
      critChanceBp: 0,
      damageType: DamageType.ice,
      ballistic: false,
      gravityScale: 1.0,
      pierce: true,
      maxPierceHits: 2,
    );

    final broadphase = BroadphaseGrid(
      index: GridIndex2D(
        cellSize: const SpatialGridTuning().broadphaseCellSize,
      ),
    )..rebuild(world);
    final hits = ProjectileHitSystem();
    final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

    hits.step(world, broadphase, currentTick: 1);
    damage.step(world, currentTick: 1);

    expect(world.health.hp[world.health.indexOf(enemyA)], 8800);
    expect(world.health.hp[world.health.indexOf(enemyB)], 8800);
    expect(world.projectile.has(projectile), isFalse);
  });

  test(
    'piercing projectile does not re-hit the same target on later ticks',
    () {
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
        health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
        mana: const ManaDef(mana: 0, manaMax: 0, regenPerSecond100: 0),
        stamina: const StaminaDef(
          stamina: 0,
          staminaMax: 0,
          regenPerSecond100: 0,
        ),
      );

      final enemy = world.createEntity();
      world.transform.add(enemy, posX: 140, posY: 100, velX: 0, velY: 0);
      world.faction.add(enemy, const FactionDef(faction: Faction.enemy));
      world.colliderAabb.add(enemy, const ColliderAabbDef(halfX: 8, halfY: 8));
      world.health.add(
        enemy,
        const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      );

      final projectile = spawnProjectileFromCaster(
        world,
        tickHz: 60,
        projectileId: ProjectileId.iceBolt,
        projectile: const ProjectileCatalog().get(ProjectileId.iceBolt),
        faction: Faction.player,
        owner: player,
        casterX: 140,
        casterY: 100,
        originOffset: 0,
        dirX: 1,
        dirY: 0,
        fallbackDirX: 1,
        fallbackDirY: 0,
        damage100: 1000,
        critChanceBp: 0,
        damageType: DamageType.ice,
        ballistic: false,
        gravityScale: 1.0,
        pierce: true,
        maxPierceHits: 3,
      );

      final broadphase = BroadphaseGrid(
        index: GridIndex2D(
          cellSize: const SpatialGridTuning().broadphaseCellSize,
        ),
      )..rebuild(world);
      final hits = ProjectileHitSystem();
      final damage = DamageSystem(invulnerabilityTicksOnHit: 0, rngSeed: 1);

      hits.step(world, broadphase, currentTick: 1);
      damage.step(world, currentTick: 1);
      final hpAfterFirst = world.health.hp[world.health.indexOf(enemy)];

      hits.step(world, broadphase, currentTick: 2);
      damage.step(world, currentTick: 2);

      expect(world.projectile.has(projectile), isTrue);
      expect(world.health.hp[world.health.indexOf(enemy)], hpAfterFirst);
    },
  );
}
