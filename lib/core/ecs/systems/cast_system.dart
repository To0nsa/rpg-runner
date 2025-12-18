import 'dart:math';

import '../../combat/faction.dart';
import '../../math/vec2.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../snapshots/enums.dart';
import '../../spells/spell_catalog.dart';
import '../../spells/spell_id.dart';
import '../../tuning/v0_ability_tuning.dart';
import '../../tuning/v0_movement_tuning.dart';
import '../entity_id.dart';
import '../world.dart';
import '../stores/lifetime_store.dart';
import '../stores/projectile_store.dart';
import '../stores/spell_origin_store.dart';

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
    final projectileId = spell.projectileId;
    if (projectileId == null) return;

    final spellStats = spell.stats;
    final proj = projectiles.base.get(projectileId);

    final mi = world.mana.indexOf(player);
    final mana = world.mana.mana[mi];
    if (mana < spellStats.manaCost) return;

    world.mana.mana[mi] = (mana - spellStats.manaCost)
        .clamp(0.0, world.mana.manaMax[mi])
        .toDouble();

    world.cooldown.castCooldownTicksLeft[ci] = abilities.castCooldownTicks;

    final ti = world.transform.indexOf(player);
    final facing = world.movement.facing[world.movement.indexOf(player)];

    final aimDir = _resolveAimDir(
      world.playerInput.aimDirX[ii],
      world.playerInput.aimDirY[ii],
      facing,
    );

    final spawnOffset = movement.base.playerRadius * 0.5;
    final origin = Vec2(
      world.transform.posX[ti] + aimDir.x * spawnOffset,
      world.transform.posY[ti] + aimDir.y * spawnOffset,
    );

    final projEntity = world.createEntity();
    world.transform.add(projEntity, pos: origin, vel: const Vec2(0, 0));
    world.projectile.add(
      projEntity,
      ProjectileDef(
        projectileId: projectileId,
        faction: Faction.player,
        owner: player,
        dirX: aimDir.x,
        dirY: aimDir.y,
        speedUnitsPerSecond: proj.speedUnitsPerSecond,
        damage: spellStats.damage,
      ),
    );
    world.spellOrigin.add(projEntity, const SpellOriginDef(spellId: spellId));
    world.lifetime.add(
      projEntity,
      LifetimeDef(ticksLeft: projectiles.lifetimeTicks(projectileId)),
    );
  }

  Vec2 _resolveAimDir(double x, double y, Facing facing) {
    if (x == 0 && y == 0) {
      return Vec2(facing == Facing.right ? 1.0 : -1.0, 0.0);
    }
    final len2 = x * x + y * y;
    if (len2 <= 1e-12) {
      return Vec2(facing == Facing.right ? 1.0 : -1.0, 0.0);
    }
    final invLen = 1.0 / sqrt(len2);
    return Vec2(x * invLen, y * invLen);
  }
}
