import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../enemies/enemy_catalog.dart';
import '../../projectiles/projectile_catalog.dart';
import '../entity_id.dart';
import '../stores/enemies/flying_enemy_combat_mode_store.dart';
import '../world.dart';

/// Plans high-level combat mode for flying enemies.
///
/// This keeps resource-based combat selection in one place so locomotion and
/// attack commit systems consume a shared decision each tick.
class FlyingEnemyCombatModeSystem {
  FlyingEnemyCombatModeSystem({
    this.enemyCatalog = const EnemyCatalog(),
    this.projectiles = const ProjectileCatalog(),
    this.abilities = AbilityCatalog.shared,
  });

  final EnemyCatalog enemyCatalog;
  final ProjectileCatalog projectiles;
  final AbilityResolver abilities;

  /// Writes combat mode for all flying enemies.
  void step(EcsWorld world) {
    final castAbility = abilities.resolve(_enemyCastAbilityId);
    final steering = world.flyingEnemySteering;
    for (var i = 0; i < steering.denseEntities.length; i += 1) {
      final enemy = steering.denseEntities[i];
      final modeIndex = world.flyingEnemyCombatMode.tryIndexOf(enemy);
      if (modeIndex == null) {
        assert(
          false,
          'FlyingEnemyCombatModeSystem requires FlyingEnemyCombatModeStore on flying enemies; add it at spawn time.',
        );
        continue;
      }

      final combatModeStore = world.flyingEnemyCombatMode;
      final currentMode = combatModeStore.mode[modeIndex];
      final requiresFallbackStrike =
          combatModeStore.requiresFallbackStrike[modeIndex];

      final nextDecision = _resolveCombatMode(
        world,
        enemy: enemy,
        castAbility: castAbility,
        currentMode: currentMode,
        requiresFallbackStrike: requiresFallbackStrike,
      );
      combatModeStore.mode[modeIndex] = nextDecision.mode;
      combatModeStore.requiresFallbackStrike[modeIndex] =
          nextDecision.requiresFallbackStrike;
    }
  }

  _CombatModeDecision _resolveCombatMode(
    EcsWorld world, {
    required EntityId enemy,
    required AbilityDef? castAbility,
    required FlyingEnemyCombatMode currentMode,
    required bool requiresFallbackStrike,
  }) {
    if (castAbility == null) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.projectile,
        requiresFallbackStrike: false,
      );
    }

    final enemyIndex = world.enemy.tryIndexOf(enemy);
    if (enemyIndex == null) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.projectile,
        requiresFallbackStrike: false,
      );
    }
    final archetype = enemyCatalog.get(world.enemy.enemyId[enemyIndex]);

    final projectileId = archetype.primaryProjectileId;
    if (projectileId == null) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.projectile,
        requiresFallbackStrike: false,
      );
    }
    final projectile = projectiles.tryGet(projectileId);
    if (projectile == null) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.projectile,
        requiresFallbackStrike: false,
      );
    }

    final fallbackMeleeAbilityId = archetype.primaryMeleeAbilityId;
    if (fallbackMeleeAbilityId == null) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.projectile,
        requiresFallbackStrike: false,
      );
    }
    final fallbackMeleeAbility = abilities.resolve(fallbackMeleeAbilityId);
    if (fallbackMeleeAbility == null ||
        fallbackMeleeAbility.hitDelivery is! MeleeHitDelivery) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.projectile,
        requiresFallbackStrike: false,
      );
    }

    final castCost = castAbility.resolveCostForWeaponType(
      projectile.weaponType,
    );
    final hasManaDeficit = _hasManaDeficit(world, enemy: enemy, cost: castCost);
    if (hasManaDeficit) {
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.meleeFallback,
        requiresFallbackStrike: true,
      );
    }

    if (currentMode == FlyingEnemyCombatMode.meleeFallback &&
        requiresFallbackStrike) {
      // Keep fallback mode latched until one melee strike commit confirms the
      // behavior transition was honored even if mana regenerated meanwhile.
      return const _CombatModeDecision(
        mode: FlyingEnemyCombatMode.meleeFallback,
        requiresFallbackStrike: true,
      );
    }

    return const _CombatModeDecision(
      mode: FlyingEnemyCombatMode.projectile,
      requiresFallbackStrike: false,
    );
  }

  bool _hasManaDeficit(
    EcsWorld world, {
    required EntityId enemy,
    required AbilityResourceCost cost,
  }) {
    if (cost.manaCost100 <= 0) return false;
    final manaIndex = world.mana.tryIndexOf(enemy);
    if (manaIndex == null) return true;
    return world.mana.mana[manaIndex] < cost.manaCost100;
  }

  static const AbilityKey _enemyCastAbilityId = 'unoco.enemy_cast';
}

class _CombatModeDecision {
  const _CombatModeDecision({
    required this.mode,
    required this.requiresFallbackStrike,
  });

  final FlyingEnemyCombatMode mode;
  final bool requiresFallbackStrike;
}
