import 'package:flutter_test/flutter_test.dart';

import 'package:runner_core/combat/damage_type.dart';
import 'package:runner_core/combat/faction.dart';
import 'package:runner_core/commands/command.dart';
import 'package:runner_core/ecs/stores/body_store.dart';
import 'package:runner_core/ecs/systems/projectile_world_collision_system.dart';
import 'package:runner_core/ecs/world.dart';
import 'package:runner_core/game_core.dart';
import '../support/test_level.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_catalog.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/players/player_tuning.dart';
import 'package:runner_core/abilities/ability_catalog.dart';
import 'package:runner_core/stats/character_stats_resolver.dart';
import 'package:runner_core/util/tick_math.dart';
import 'package:runner_core/projectiles/spawn_projectile_item.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/ecs/stores/combat/equipped_loadout_store.dart';

import '../support/test_player.dart';
import '../test_tunings.dart';

void main() {
  test(
    'projectile spell: sufficient mana => projectile spawns + costs + cooldown set',
    () {
      const tickHz = 20;
      final base = PlayerCharacterRegistry.eloise;
      final catalog = testPlayerCatalog(
        bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
        projectileId: ProjectileId.fireBolt,
        projectileSlotSpellId: null,
        abilityProjectileId: 'eloise.quick_shot',
      );
      final core = GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 1,
        tickHz: tickHz,
        playerCharacter: base.copyWith(
          catalog: catalog,
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 10,
              playerManaRegenPerSecond: 0,
              playerStaminaMax: 0,
              playerStaminaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      final playerPosX = core.playerPosX;
      final playerPosY = core.playerPosY;
      final initialHud = core.buildSnapshot().hud;

      core.applyCommands(const [
        AimDirCommand(tick: 1, x: 1, y: 0),
        ProjectilePressedCommand(tick: 1),
      ]);
      core.stepOneTick();

      final windupTicks = ticksFromSecondsCeil(
        AbilityCatalog.shared.resolve('eloise.quick_shot')!.windupTicks / 60.0,
        tickHz,
      );
      for (var i = 0; i < windupTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final snapshot = core.buildSnapshot();
      final projectiles = snapshot.entities
          .where((e) => e.kind == EntityKind.projectile)
          .toList();
      expect(projectiles.length, 1);

      final p = projectiles.single;
      final item = const ProjectileCatalog().get(ProjectileId.fireBolt);
      expect(p.pos.x, closeTo(playerPosX + item.originOffset, 1e-9));
      expect(p.pos.y, closeTo(playerPosY, 1e-9));

      final ability = AbilityCatalog.shared.resolve('eloise.quick_shot')!;
      final shotCost = ability.resolveCostForWeaponType(WeaponType.spell);
      expect(
        snapshot.hud.mana,
        closeTo(initialHud.mana - (shotCost.manaCost100 / 100.0), 1e-9),
      );
      expect(snapshot.hud.stamina, closeTo(initialHud.stamina, 1e-9));
      final resolvedStats = const CharacterStatsResolver().resolveLoadout(
        EquippedLoadoutDef(
          mask: catalog.loadoutSlotMask,
          mainWeaponId: catalog.weaponId,
          offhandWeaponId: catalog.offhandWeaponId,
          spellBookId: catalog.spellBookId,
          projectileSlotSpellId: catalog.projectileSlotSpellId,
          abilityPrimaryId: catalog.abilityPrimaryId,
          abilitySecondaryId: catalog.abilitySecondaryId,
          abilityProjectileId: catalog.abilityProjectileId,
          abilitySpellId: catalog.abilitySpellId,
          abilityMobilityId: catalog.abilityMobilityId,
          abilityJumpId: catalog.abilityJumpId,
        ),
      );
      final cooldownTicks = resolvedStats.applyCooldownReduction(
        ticksFromSecondsCeil(ability.cooldownTicks / 60.0, tickHz),
      );
      expect(
        snapshot.hud.cooldownTicksLeft[CooldownGroup.projectile],
        cooldownTicks - windupTicks,
      ); // Cooldown already ticked during windup
    },
  );

  test(
    'projectile spell: insufficient mana => no projectile + no costs + no cooldown',
    () {
      final base = PlayerCharacterRegistry.eloise;
      final core = GameCore(
        levelDefinition: testFieldLevel(tuning: noAutoscrollTuning),
        seed: 1,
        tickHz: 20,
        playerCharacter: base.copyWith(
          catalog: testPlayerCatalog(
            bodyTemplate: BodyDef(isKinematic: true, useGravity: false),
            projectileId: ProjectileId.fireBolt,
            projectileSlotSpellId: null,
            abilityProjectileId: 'eloise.quick_shot',
          ),
          tuning: base.tuning.copyWith(
            resource: const ResourceTuning(
              playerManaMax: 0,
              playerManaRegenPerSecond: 0,
              playerStaminaMax: 10,
              playerStaminaRegenPerSecond: 0,
            ),
          ),
        ),
      );

      final initialHud = core.buildSnapshot().hud;

      core.applyCommands(const [
        AimDirCommand(tick: 1, x: 1, y: 0),
        ProjectilePressedCommand(tick: 1),
      ]);
      core.stepOneTick();

      final windupTicks = ticksFromSecondsCeil(
        AbilityCatalog.shared.resolve('eloise.quick_shot')!.windupTicks / 60.0,
        core.tickHz,
      );
      for (var i = 0; i < windupTicks; i += 1) {
        core.applyCommands(const <Command>[]);
        core.stepOneTick();
      }

      final snapshot = core.buildSnapshot();
      expect(
        snapshot.entities.where((e) => e.kind == EntityKind.projectile),
        isEmpty,
      );
      expect(snapshot.hud.mana, closeTo(initialHud.mana, 1e-9));
      expect(snapshot.hud.stamina, closeTo(initialHud.stamina, 1e-9));
      expect(snapshot.hud.cooldownTicksLeft[CooldownGroup.projectile], 0);
      expect(snapshot.hud.canAffordProjectile, isFalse);
    },
  );

  test('ProjectileWorldCollisionSystem despawns ballistic projectiles', () {
    final world = EcsWorld();
    final system = ProjectileWorldCollisionSystem();
    final projectile = const ProjectileCatalog().get(ProjectileId.iceBolt);

    final owner = world.createEntity();
    final p = spawnProjectileFromCaster(
      world,
      tickHz: 20,
      projectileId: ProjectileId.iceBolt,
      projectile: projectile,
      faction: Faction.player,
      owner: owner,
      casterX: 100,
      casterY: 50,
      originOffset: 0,
      dirX: 1,
      dirY: 0,
      fallbackDirX: 1,
      fallbackDirY: 0,
      damage100: 100,
      critChanceBp: 0,
      damageType: DamageType.physical,
      ballistic: true,
      gravityScale: 1.0,
    );

    expect(world.projectile.has(p), isTrue);
    expect(world.body.has(p), isTrue);
    expect(world.collision.has(p), isTrue);
    expect(world.projectile.usePhysics[world.projectile.indexOf(p)], isTrue);

    final ci = world.collision.indexOf(p);
    world.collision.grounded[ci] = true;

    system.step(world);

    expect(world.projectile.has(p), isFalse);
    expect(world.collision.has(p), isFalse);
  });
}
