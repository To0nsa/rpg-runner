import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/ecs/entity_factory.dart';
import 'package:rpg_runner/core/ecs/systems/projectile_launch_system.dart';
import 'package:rpg_runner/core/ecs/systems/anim/anim_system.dart';
import 'package:rpg_runner/core/ecs/stores/projectile_intent_store.dart';
import 'package:rpg_runner/core/abilities/ability_def.dart';
import 'package:rpg_runner/core/projectiles/projectile_catalog.dart';
import 'package:rpg_runner/core/projectiles/projectile_id.dart';
import 'package:rpg_runner/core/players/player_character_registry.dart';
import 'package:rpg_runner/core/players/player_catalog.dart';
import 'package:rpg_runner/core/players/player_tuning.dart';
import 'package:rpg_runner/core/enemies/enemy_catalog.dart';
import 'package:rpg_runner/core/snapshots/enums.dart';
import 'package:rpg_runner/core/combat/damage_type.dart';

void main() {
  test('Phase 6 Unit Test: ProjectileLaunchSystem + AnimSystem', () {
    final world = EcsWorld(seed: 123);
    final entityFactory = EntityFactory(world);

    // Setup player
    final playerArchetype = PlayerCatalogDerived.from(
      PlayerCharacterRegistry.defaultCharacter.catalog,
      movement: MovementTuningDerived.from(const MovementTuning(), tickHz: 60),
      resources: ResourceTuningDerived.from(const ResourceTuning()),
    ).archetype;

    final player = entityFactory.createPlayer(
      posX: 0,
      posY: 0,
      velX: 0,
      velY: 0,
      facing: Facing.right,
      grounded: true,
      body: playerArchetype.body,
      collider: playerArchetype.collider,
      health: playerArchetype.health,
      mana: playerArchetype.mana,
      stamina: playerArchetype.stamina,
    );

    // Setup Systems
    final tickHz = 60;

    final projectileLaunchSystem = ProjectileLaunchSystem(
      projectiles: const ProjectileCatalog(),
      tickHz: tickHz,
    );

    final animSystem = AnimSystem(
      tickHz: tickHz,
      enemyCatalog: const EnemyCatalog(),
      playerMovement: MovementTuningDerived.from(
        const MovementTuning(),
        tickHz: tickHz,
      ),
      playerAnimTuning: AnimTuningDerived.from(
        const AnimTuning(),
        tickHz: tickHz,
      ),
    );

    final tick = 100; // Arbitrary current tick

    // Inject Intent
    world.projectileIntent.set(
      player,
      ProjectileIntentDef(
        projectileId: ProjectileId.iceBolt,
        abilityId: 'eloise.charged_shot',
        slot: AbilitySlot.projectile,
        dirX: 1.0,
        dirY: 0.0,
        fallbackDirX: 1.0,
        fallbackDirY: 0.0,
        damage100: 1500,
        staminaCost100: 0,
        manaCost100: 1000,
        pierce: false,
        maxPierceHits: 1,
        damageType: DamageType.ice,
        procs: const [],
        ballistic: false,
        gravityScale: 1.0,
        originOffset: 0.5,
        commitTick: tick,
        windupTicks: 0,
        activeTicks: 1,
        recoveryTicks: 0,
        cooldownTicks: 60,
        cooldownGroupId: CooldownGroup.projectile,
        tick: tick,
      ),
    );

    // Force Resources
    if (world.mana.has(player)) {
      world.mana.mana[world.mana.indexOf(player)] = 10000;
    }
    if (world.cooldown.has(player)) {
      world.cooldown.setTicksLeft(player, CooldownGroup.projectile, 0);
    }

    // Step ProjectileLaunchSystem
    projectileLaunchSystem.step(world, currentTick: tick);

    // Simulate AbilityActivationSystem's side effect (setting active ability)
    world.activeAbility.set(
      player,
      id: 'eloise.charged_shot',
      slot: AbilitySlot.projectile,
      commitTick: tick,
      windupTicks: 0,
      activeTicks: 1,
      recoveryTicks: 0,
      facingDir: Facing.right,
    );

    // Verify ActiveAbility
    expect(
      world.activeAbility.hasActiveAbility(player),
      isTrue,
      reason: 'ActiveAbility should be set by ProjectileLaunchSystem',
    );
    final activeId =
        world.activeAbility.abilityId[world.activeAbility.indexOf(player)];
    expect(activeId, equals('eloise.charged_shot'));

    // Step AnimSystem
    animSystem.step(world, player: player, currentTick: tick);

    // Verify AnimState
    final anim = world.animState.anim[world.animState.indexOf(player)];
    expect(anim, equals(AnimKey.ranged), reason: 'Animation should be Ranged');
  });
}
