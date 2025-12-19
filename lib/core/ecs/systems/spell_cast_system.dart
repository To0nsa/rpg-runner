import '../../spells/spawn_spell_projectile.dart';
import '../../spells/spell_catalog.dart';
import '../../util/double_math.dart';
import '../world.dart';
import '../../projectiles/projectile_catalog.dart';

/// Executes `CastIntentStore` intents by applying costs/cooldowns and spawning
/// spell projectiles.
///
/// IMPORTANT:
/// - Only intents with `intent.tick == currentTick` are considered valid.
/// - Mana spending + cooldown start happen only if a projectile was spawned.
/// - Intents are invalidated after processing by setting `intent.tick = -1`.
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

    for (var ii = 0; ii < intents.denseEntities.length; ii += 1) {
      if (intents.tick[ii] != currentTick) continue;

      final caster = intents.denseEntities[ii];

      // Invalidate now so accidental multi-pass execution in the same tick cannot
      // double-cast. (Intent is still ignored next tick due to stamp mismatch.)
      intents.tick[ii] = -1;

      if (!world.transform.has(caster)) continue;
      if (!world.cooldown.has(caster)) continue;
      if (!world.mana.has(caster)) continue;

      final ci = world.cooldown.indexOf(caster);
      if (world.cooldown.castCooldownTicksLeft[ci] > 0) continue;

      final spellId = intents.spellId[ii];
      final def = spells.get(spellId);

      final mi = world.mana.indexOf(caster);
      final mana = world.mana.mana[mi];
      if (mana < def.stats.manaCost) continue;

      final fi = world.faction.tryIndexOf(caster);
      if (fi == null) continue;
      final faction = world.faction.faction[fi];

      final ti = world.transform.indexOf(caster);
      final spawned = spawnSpellProjectileFromCaster(
        world,
        spells: spells,
        projectiles: projectiles,
        spellId: spellId,
        faction: faction,
        owner: caster,
        casterX: world.transform.posX[ti],
        casterY: world.transform.posY[ti],
        originOffset: intents.originOffset[ii],
        dirX: intents.dirX[ii],
        dirY: intents.dirY[ii],
        fallbackDirX: intents.fallbackDirX[ii],
        fallbackDirY: intents.fallbackDirY[ii],
      );
      if (spawned == null) continue;

      world.mana.mana[mi] = clampDouble(
        mana - def.stats.manaCost,
        0.0,
        world.mana.manaMax[mi],
      );
      world.cooldown.castCooldownTicksLeft[ci] = intents.cooldownTicks[ii];
    }
  }
}
