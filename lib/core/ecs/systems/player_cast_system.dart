import '../../combat/faction.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_catalog.dart';
import '../../spells/spell_id.dart';
import '../../spells/spawn_spell_projectile.dart';
import '../../util/double_math.dart';
import '../../tuning/v0_ability_tuning.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../world.dart';

class PlayerCastSystem {
  PlayerCastSystem({
    required this.spells,
    required this.projectiles,
    required this.abilities,
    required this.movement,
  });

  final SpellCatalog spells;
  final ProjectileCatalogDerived projectiles;
  final V0AbilityTuningDerived abilities;
  final V0MovementTuningDerived movement;

  void step(EcsWorld world, {required EntityId player}) {
    if (!world.playerInput.has(player) ||
        !world.transform.has(player) ||
        !world.movement.has(player) ||
        !world.mana.has(player) ||
        !world.cooldown.has(player)) {
      return;
    }

    final ii = world.playerInput.indexOf(player);
    if (!world.playerInput.castPressed[ii]) return;

    final ci = world.cooldown.indexOf(player);
    if (world.cooldown.castCooldownTicksLeft[ci] > 0) return;

    const spellId = SpellId.iceBolt;
    final spell = spells.get(spellId);
    final spellStats = spell.stats;

    final mi = world.mana.indexOf(player);
    final mana = world.mana.mana[mi];
    if (mana < spellStats.manaCost) return;

    final ti = world.transform.indexOf(player);
    final facing = world.movement.facing[world.movement.indexOf(player)];

    final rawAimX = world.playerInput.aimDirX[ii];
    final rawAimY = world.playerInput.aimDirY[ii];

    final spawnOffset = movement.base.playerRadius * 0.5;
    final fallbackDirX = facing == Facing.right ? 1.0 : -1.0;

    // IMPORTANT: `spawnSpellProjectileFromCaster` owns:
    // - "is this spell a projectile?" checks
    // - direction normalization (with facing fallback)
    // Only spend mana / start cooldown if a projectile was actually spawned.
    final spawned = spawnSpellProjectileFromCaster(
      world,
      spells: spells,
      projectiles: projectiles,
      spellId: spellId,
      faction: Faction.player,
      owner: player,
      casterX: world.transform.posX[ti],
      casterY: world.transform.posY[ti],
      originOffset: spawnOffset,
      dirX: rawAimX,
      dirY: rawAimY,
      fallbackDirX: fallbackDirX,
      fallbackDirY: 0.0,
    );
    if (spawned == null) return;

    world.mana.mana[mi] = clampDouble(
      mana - spellStats.manaCost,
      0.0,
      world.mana.manaMax[mi],
    );

    world.cooldown.castCooldownTicksLeft[ci] = abilities.castCooldownTicks;
  }
}
