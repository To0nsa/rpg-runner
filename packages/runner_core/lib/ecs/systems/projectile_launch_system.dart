import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/spawn_projectile_item.dart';
import '../stores/projectile_intent_store.dart';
import '../world.dart';

/// Executes [ProjectileIntentStore] intents by spawning projectiles.
///
/// **Execution Only**:
/// - Reads committed intents (`tick == currentTick`).
/// - Spawns projectile entities.
/// - Does **not** deduct resources or start cooldowns (handled by Activation).
class ProjectileLaunchSystem {
  ProjectileLaunchSystem({
    required this.projectiles,
    required this.tickHz,
    this.abilities = AbilityCatalog.shared,
  });
  final AbilityResolver abilities;

  final ProjectileCatalog projectiles;
  final int tickHz;

  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.projectileIntent;
    if (intents.denseEntities.isEmpty) return;

    final transforms = world.transform;
    final factions = world.faction;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final caster = intents.denseEntities[ii];
      final executeTick = intents.tick[ii];

      final ti = transforms.tryIndexOf(caster);
      if (ti == null) {
        _invalidateIntent(intents, ii);
        continue;
      }

      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);

      final fi = factions.tryIndexOf(caster);
      if (fi == null) continue;
      final projectileId = intents.projectileId[ii];
      final projectile = projectiles.get(projectileId);
      final delivery = abilities.resolve(intents.abilityId[ii])?.hitDelivery;
      final bomb = delivery is BombHitDelivery ? delivery : null;
      final fan = delivery is ProjectileHitDelivery ? delivery : null;
      final shots = max(projectile.shotCount, fan?.shotCount ?? 1);
      final spread = max(projectile.spreadRadians, fan?.spreadRadians ?? 0);
      final damage = intents.damage100[ii] * projectile.damageScaleBp ~/ 10000;
      final angle = atan2(intents.dirY[ii], intents.dirX[ii]);
      for (var shot = 0; shot < shots; shot++) {
        final shotAngle =
            angle + (shots == 1 ? 0 : spread * (shot / (shots - 1) - .5));

        final spawned = spawnProjectileFromCaster(
          world,
          tickHz: tickHz,
          currentTick: currentTick,
          projectileId: projectileId,
          projectile: projectile,
          faction: factions.faction[fi],
          owner: caster,
          casterX: transforms.posX[ti] + intents.sourceOffsetX[ii],
          casterY:
              transforms.posY[ti] +
              intents.sourceOffsetY[ii] +
              (bomb == null ? 0 : 8),
          originOffset: bomb == null ? intents.originOffset[ii] : 0,
          dirX: bomb != null
              ? 1
              : shots == 1
              ? intents.dirX[ii]
              : cos(shotAngle),
          dirY: bomb != null
              ? 0
              : shots == 1
              ? intents.dirY[ii]
              : sin(shotAngle),
          fallbackDirX: intents.fallbackDirX[ii],
          fallbackDirY: intents.fallbackDirY[ii],
          // Remainder is allocated deterministically, preserving the exact budget.
          damage100: damage ~/ shots + (shot < damage % shots ? 1 : 0),
          critChanceBp: intents.critChanceBp[ii],
          damageType: intents.damageType[ii],
          procs: intents.procs[ii],
          knockback: intents.knockback[ii],
          pierce: intents.pierce[ii],
          maxPierceHits: intents.maxPierceHits[ii],
          ballistic: intents.ballistic[ii],
          gravityScale: intents.gravityScale[ii],
          speedScale: intents.speedScaleBp[ii] / 10000.0,
        );
        if (bomb != null) {
          world.bomb.add(
            spawned,
            explodeTick: currentTick + (bomb.fuseTicks * tickHz / 60).ceil(),
            radius: bomb.radius,
          );
        }
      }
    }
  }

  void _invalidateIntent(ProjectileIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
