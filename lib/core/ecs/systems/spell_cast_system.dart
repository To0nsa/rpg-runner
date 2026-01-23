import '../../spells/spawn_spell_projectile.dart';
import '../../spells/spell_catalog.dart';
import '../../util/double_math.dart';
import '../world.dart';
import '../../projectiles/projectile_catalog.dart';

/// Executes [CastIntentStore] intents by spawning projectiles and managing resources.
///
/// **Responsibilities**:
/// - Consumes [CastIntent] stamped with the `currentTick`.
/// - Checks validation (Cooldowns, Mana cost, Entity existence).
/// - Spawns Spell Projectiles via [spawnSpellProjectileFromCaster].
/// - Deducts Mana and applies Cooldown IF spawn succeeds.
///
/// **Logic**:
/// - Intents are processed only once per tick.
/// - Invalidated immediately (`tick = -1`) to prevent double-execution.
class SpellCastSystem {
  SpellCastSystem({
    required this.spells,
    required this.projectiles,
  });

  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;

  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.castIntent;
    if (intents.denseEntities.isEmpty) return;

    // Cache stores for efficient access
    final transforms = world.transform;
    final cooldowns = world.cooldown;
    final manas = world.mana;
    final factions = world.faction;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      if (intents.tick[ii] != currentTick) continue;

      final caster = intents.denseEntities[ii];

      // Safe-guard: Invalidate intent immediately to prevent re-entry within the same tick.
      intents.tick[ii] = -1;

      // -- Validation Checks --
      // Must have position, cooldowns, and mana components.
      final ti = transforms.tryIndexOf(caster);

      if (ti == null) continue;

      // Cannot cast while stunned.
      if (world.controlLock.isStunned(caster, currentTick)) continue;

      final ci = cooldowns.tryIndexOf(caster);
      if (ci == null) continue;
      
      // Check cooldown (must be ready).
      if (cooldowns.castCooldownTicksLeft[ci] > 0) continue;

      final mi = manas.tryIndexOf(caster);
      if (mi == null) continue;

      // Check Mana Cost (Phase 4: from Intent)
      final currentMana = manas.mana[mi];
      final manaCost = intents.manaCost[ii];
      
      if (currentMana < manaCost) continue;

      // Faction is optional generally, but required for projectile ownership usually.
      final fi = factions.tryIndexOf(caster);
      if (fi == null) continue;
      final faction = factions.faction[fi];

      // -- Execution --
      final spawned = spawnSpellProjectileFromCaster(
        world,
        spells: spells,
        projectiles: projectiles,
        spellId: spellId,
        faction: faction,
        owner: caster,
        casterX: transforms.posX[ti],
        casterY: transforms.posY[ti],
        originOffset: intents.originOffset[ii],
        dirX: intents.dirX[ii],
        dirY: intents.dirY[ii],
        fallbackDirX: intents.fallbackDirX[ii],
        fallbackDirY: intents.fallbackDirY[ii],
        // Phase 4 Overrides
        overrideProjectileId: intents.projectileId[ii],
        overrideDamage: intents.damage[ii],
        overrideDamageType: intents.damageType[ii],
        overrideStatusProfileId: intents.statusProfileId[ii],
      );

      // Only apply costs if the spell actually did something (spawned).
      if (spawned == null) continue;

      manas.mana[mi] = clampDouble(
        currentMana - manaCost,
        0.0,
        manas.manaMax[mi],
      );
      
      cooldowns.castCooldownTicksLeft[ci] = intents.cooldownTicks[ii];
    }
  }
}
