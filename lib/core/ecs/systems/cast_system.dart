import 'dart:math';

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

class CastSystem {
  CastSystem({
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
    if (spell.projectileId == null) return;

    final spellStats = spell.stats;

    final mi = world.mana.indexOf(player);
    final mana = world.mana.mana[mi];
    if (mana < spellStats.manaCost) return;

    world.mana.mana[mi] = clampDouble(
      mana - spellStats.manaCost,
      0.0,
      world.mana.manaMax[mi],
    );

    world.cooldown.castCooldownTicksLeft[ci] = abilities.castCooldownTicks;

    final ti = world.transform.indexOf(player);
    final facing = world.movement.facing[world.movement.indexOf(player)];

    final rawAimX = world.playerInput.aimDirX[ii];
    final rawAimY = world.playerInput.aimDirY[ii];

    double aimX;
    double aimY;
    if (rawAimX == 0 && rawAimY == 0) {
      aimX = facing == Facing.right ? 1.0 : -1.0;
      aimY = 0.0;
    } else {
      final len2 = rawAimX * rawAimX + rawAimY * rawAimY;
      if (len2 <= 1e-12) {
        aimX = facing == Facing.right ? 1.0 : -1.0;
        aimY = 0.0;
      } else {
        final invLen = 1.0 / sqrt(len2);
        aimX = rawAimX * invLen;
        aimY = rawAimY * invLen;
      }
    }

    final spawnOffset = movement.base.playerRadius * 0.5;
    final originX = world.transform.posX[ti] + aimX * spawnOffset;
    final originY = world.transform.posY[ti] + aimY * spawnOffset;

    spawnSpellProjectile(
      world,
      spells: spells,
      projectiles: projectiles,
      spellId: spellId,
      faction: Faction.player,
      owner: player,
      originX: originX,
      originY: originY,
      dirX: aimX,
      dirY: aimY,
    );
  }
}
