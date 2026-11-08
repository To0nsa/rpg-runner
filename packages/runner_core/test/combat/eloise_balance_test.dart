import 'package:test/test.dart';
import 'package:runner_core/snapshot_builder.dart';
import 'package:runner_core/snapshots/player_hud_snapshot.dart';
import 'package:runner_core/snapshots/camera_snapshot.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_identity.dart';
import 'package:runner_core/loadout/loadout_validator.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/accessories/accessory_catalog.dart';
import 'package:runner_core/combat/status/status.dart';
import 'package:runner_core/ecs/entity_factory.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/stores/collider_aabb_store.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';
import 'package:runner_core/ecs/stores/health_store.dart';
import 'package:runner_core/ecs/stores/mana_store.dart';
import 'package:runner_core/ecs/stores/stamina_store.dart';
import 'package:runner_core/ecs/systems/ability_activation_system.dart';
import 'package:runner_core/ecs/systems/active_ability_phase_system.dart';
import 'package:runner_core/ecs/systems/hold_ability_system.dart';
import 'package:runner_core/ecs/systems/self_ability_system.dart';
import 'package:runner_core/ecs/systems/status_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/spellBook/spell_book_catalog.dart';
import 'package:runner_core/weapons/weapon_catalog.dart';
import 'package:runner_core/weapons/weapon_id.dart';

void main() {
  for (final hz in [30, 60, 90]) {
    test('Cleave earns innate bleed at full charge only at $hz Hz', () {
      final threshold = (20 * hz / 60).ceil();
      for (final weapon in [WeaponId.plainsteel, WeaponId.waspfang]) {
        for (final held in [0, threshold - 1, threshold]) {
          final f = _Fixture(
            hz,
            EquippedLoadoutDef(
              mainWeaponId: weapon,
              abilityPrimaryId: 'eloise.bloodletter_cleave',
            ),
          );
          final offset = f.world.abilityCharge.slotOffsetForDenseIndex(
            0,
            AbilitySlot.primary,
          );
          f.world.abilityCharge.releasedHoldTicksBySlot[offset] = held;
          f.world.abilityCharge.releasedTickBySlot[offset] = 100;
          f.world.playerInput.strikePressed[0] = true;
          f.activation.step(f.world, player: f.player, currentTick: 100);
          final procs = f.world.meleeIntent.procs.single;
          if (held == threshold) {
            expect(procs, hasLength(1));
            expect(procs.single.statusProfileId, StatusProfileId.meleeBleed);
            expect(procs.single.chanceBp, 10000);
          } else if (weapon == WeaponId.waspfang) {
            expect(
              procs.single.chanceBp,
              2000,
              reason: 'Uncharged item proc survives',
            );
          } else {
            expect(procs, isEmpty);
          }
        }
      }
    });

    test(
      'Riposte survives long guard then expires after release at $hz Hz',
      () {
        final f = _Fixture(hz, const EquippedLoadoutDef());
        final windup = (2 * hz / 60).ceil();
        f.world.activeAbility.set(
          f.player,
          id: 'eloise.aegis_riposte',
          slot: AbilitySlot.secondary,
          commitTick: 0,
          windupTicks: windup,
          activeTicks: 3 * hz,
          recoveryTicks: windup,
          facingDir: Facing.right,
        );
        f.world.riposte.grant(
          f.player,
          expiresAtTick: windup + hz,
          bonusBp: 10000,
          guardStartTick: 0,
          releaseWindowTicks: hz,
        );
        final hold = HoldAbilitySystem(
          tickHz: hz,
          abilities: AbilityCatalog.shared,
        );
        final phases = ActiveAbilityPhaseSystem();
        final release = hz * 2;
        for (var tick = windup; tick <= release; tick++) {
          f.world.playerInput.setAbilitySlotHeld(
            f.player,
            AbilitySlot.secondary,
            tick < release,
          );
          phases.step(f.world, currentTick: tick);
          hold.step(f.world, currentTick: tick);
        }
        expect(f.world.riposte.expiresTick.single, release + hz);
        expect(f.world.riposte.ticksLeft(f.player, release + hz), 1);
        expect(f.world.riposte.ticksLeft(f.player, release + hz + 1), 0);
        f.world.riposte.sustainGuard(f.player, release + 1, release + hz + 2);
        expect(f.world.riposte.expiresTick.single, release + hz);
        f.world.destroyEntity(f.player);
        final recycled = f.world.createEntity();
        f.world.riposte.grant(recycled, expiresAtTick: 5, bonusBp: 100);
        expect(f.world.riposte.guardStartTick.single, -1);
        expect(f.world.riposte.releaseWindowTicks.single, 0);
      },
    );

    for (final entry in [
      ('eloise.vital_surge', 2000),
      ('eloise.second_wind', 1800),
    ]) {
      test('${entry.$1} pays cost and restores 25% at $hz Hz', () {
        final f = _Fixture(hz, EquippedLoadoutDef(abilitySpellId: entry.$1));
        f.world.health.hp[0] = 1000;
        f.world.stamina.stamina[0] = 1000;
        final status = f.cast();
        expect(f.world.mana.mana.single, 10000 - entry.$2);
        for (var i = 0; i < hz * 5; i++) {
          status.tickExisting(f.world);
        }
        expect(
          entry.$1 == 'eloise.vital_surge'
              ? f.world.health.hp.single
              : f.world.stamina.stamina.single,
          3500,
        );
      });
    }
    test('Haste expires before cooldown at $hz Hz', () {
      final f = _Fixture(
        hz,
        const EquippedLoadoutDef(abilitySpellId: 'eloise.arcane_haste'),
      );
      final status = f.cast();
      expect(f.world.haste.magnitude.single, 4000);
      expect(f.world.haste.ticksLeft.single, hz * 3);
      expect(
        f.world.selfIntent.cooldownTicks.single - hz * 3,
        greaterThanOrEqualTo(hz * 4),
      );
      for (var i = 0; i < hz * 3; i++) {
        status.tickExisting(f.world);
      }
      expect(f.world.haste.has(f.player), isFalse);
    });
  }
  test('snapshot projects guard reward, countdown, consumption and terminal clearing', () {
    final f = _Fixture(60, const EquippedLoadoutDef());
    f.world.activeAbility.set(
      f.player,
      id: 'eloise.aegis_riposte',
      slot: AbilitySlot.secondary,
      commitTick: 10,
      windupTicks: 0,
      activeTicks: 180,
      recoveryTicks: 2,
      facingDir: Facing.right,
    );
    f.world.riposte.grant(
      f.player,
      expiresAtTick: 90,
      bonusBp: 10000,
      guardStartTick: 10,
      releaseWindowTicks: 60,
    );
    final held = f.hud(30);
    expect(held.riposteGuarding, isTrue);
    expect(held.riposteTicksLeft, 60);
    f.world.activeAbility.clear(f.player);
    expect(f.hud(60).riposteGuarding, isFalse);
    expect(f.hud(60).riposteTicksLeft, 30);
    expect(f.hud(60, gameOver: true).riposteTicksLeft, 0);
    expect(f.hud(90).riposteTicksLeft, 0);
    f.world.riposte.consume(f.player);
    expect(f.hud(60).riposteTicksLeft, 0);
    expect(
      held.riposteTicksLeft,
      60,
      reason: 'Prior snapshots remain immutable',
    );
  });

  test('Quick Shot can commit again after its shorter execution', () {
    final f = _Fixture(
      60,
      const EquippedLoadoutDef(abilityProjectileId: 'eloise.quick_shot'),
    );
    f.world.playerInput.projectilePressed[0] = true;
    f.activation.step(f.world, player: f.player, currentTick: 1);
    final firstCost = f.world.mana.mana.single;
    for (var tick = 2; tick <= 16; tick++) {
      f.world.playerInput.projectilePressed[0] = tick == 16;
      f.world.cooldown.tickAll();
      const ActiveAbilityPhaseSystem().step(f.world, currentTick: tick);
      f.activation.step(f.world, player: f.player, currentTick: tick);
    }
    // Strength Belt adds a 5% cooldown penalty: ceil(14 * 1.05) = 15.
    expect(f.world.activeAbility.cooldownTicks.single, 15);
    expect(f.world.projectileIntent.commitTick.single, 16);
    expect(f.world.mana.mana.single, lessThan(firstCost));
    expect(f.world.projectileIntent.windupTicks.single, 6);
    expect(f.world.projectileIntent.recoveryTicks.single, 6);
  });

  test('local utility tuning preserves Willow and item-granted profiles', () {
    const profiles = StatusProfileCatalog();
    final willow = AbilityCatalog.shared.resolve(
      'bounty_hunter.hunters_focus',
    )!;
    expect(
      profiles
          .resolve(willow.selfStatusProfileId, tuning: willow.selfStatusTuning)
          .applications
          .single
          .durationSeconds,
      5,
    );
    expect(
      profiles.get(StatusProfileId.restoreHealth).applications.single.magnitude,
      3500,
    );
    expect(
      profiles.get(StatusProfileId.speedBoost).applications.single.magnitude,
      5000,
    );
  });
}

class _Fixture {
  _Fixture(this.hz, EquippedLoadoutDef loadout) {
    player = EntityFactory(world).createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: const BodyDef(isKinematic: true, useGravity: false),
      collider: const ColliderAabbDef(halfX: 8, halfY: 8),
      health: const HealthDef(hp: 10000, hpMax: 10000, regenPerSecond100: 0),
      mana: const ManaDef(mana: 10000, manaMax: 10000, regenPerSecond100: 0),
      stamina: const StaminaDef(
        stamina: 10000,
        staminaMax: 10000,
        regenPerSecond100: 0,
      ),
      equippedLoadout: loadout,
    );
    activation = AbilityActivationSystem(
      tickHz: hz,
      inputBufferTicks: 8,
      abilities: AbilityCatalog.shared,
      weapons: const WeaponCatalog(),
      projectiles: const ProjectileCatalog(),
      spellBooks: const SpellBookCatalog(),
      accessories: const AccessoryCatalog(),
    );
  }
  final int hz;
  final world = EcsWorld();
  late final int player;
  late final AbilityActivationSystem activation;
  PlayerHudSnapshot hud(int tick, {bool gameOver = false}) {
    final builder = SnapshotBuilder(
      tickHz: hz,
      world: world,
      player: player,
      movement: MovementTuningDerived.from(const MovementTuning(), tickHz: hz),
      abilities: AbilityTuningDerived.from(const AbilityTuning(), tickHz: hz),
      resources: ResourceTuningDerived.from(const ResourceTuning()),
      enemyCatalog: const EnemyCatalog(),
      weaponCatalog: const WeaponCatalog(),
      projectileCatalog: const ProjectileCatalog(),
      spellBookCatalog: const SpellBookCatalog(),
      loadoutValidator: const LoadoutValidator(
        abilityCatalog: AbilityCatalog.shared,
        weaponCatalog: WeaponCatalog(),
        projectileCatalog: ProjectileCatalog(),
        spellBookCatalog: SpellBookCatalog(),
      ),
    );
    return builder
        .build(
          tick: tick,
          runId: 1,
          seed: 1,
          levelIdentity: const RegisteredLevelIdentity(LevelId.field),
          visualThemeId: null,
          distance: 0,
          paused: false,
          gameOver: gameOver,
          camera: const CameraSnapshot(
            centerX: 0,
            centerY: 0,
            viewWidth: 600,
            viewHeight: 270,
          ),
          collectibles: 0,
          collectibleScore: 0,
          staticPrefabSprites: const [],
        )
        .hud;
  }

  StatusSystem cast() {
    world.playerInput.spellPressed[0] = true;
    activation.step(world, player: player, currentTick: 1);
    final status = StatusSystem(tickHz: hz);
    SelfAbilitySystem(tickHz: hz)
        .step(world, currentTick: 1, queueStatus: status.queue);
    status.applyQueued(world, currentTick: 1);
    return status;
  }
}
