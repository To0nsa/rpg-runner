import 'dart:math';

import '../../abilities/ability_catalog.dart';
import '../../abilities/ability_def.dart';
import '../../combat/aim_motion_forecast.dart';
import '../../projectiles/bomb_throw_aim.dart';
import '../../tuning/physics_tuning.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../players/player_character_definition.dart';
import '../../snapshots/enums.dart';
import '../world_support_view.dart';
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
  /// Bomb forecasts must use the run's physics and published terrain, matching
  /// activation. Isolated free-motion callers may omit the terrain callbacks.
  ProjectileLaunchSystem({
    required this.projectiles,
    required this.tickHz,
    this.abilities = AbilityCatalog.shared,
    this.playerCharacter,
    PhysicsTuning physics = const PhysicsTuning(),
    AimTerrain Function()? aimTerrainProvider,
    bool Function(double, double, double, double)? projectileAimPathClear,
  }) : _bombAim = BombThrowAim(
         tickHz: tickHz,
         physics: physics,
         terrainProvider: aimTerrainProvider,
         pathClear: projectileAimPathClear,
       );
  final AbilityResolver abilities;
  final BombThrowAim _bombAim;

  final ProjectileCatalog projectiles;
  final int tickHz;

  /// Supplies player-only weapon-tip attachments; autonomous actors retain
  /// their committed source offsets. Must match the run's selected character.
  final PlayerCharacterDefinition? playerCharacter;

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
      final character = playerCharacter;
      final muzzle = bomb == null && world.playerInput.has(caster)
          ? character?.projectileMuzzles[projectileId]
          : null;
      final offset = muzzle?.offset(
        renderAnim: character!.renderAnim,
        grounded: WorldSupportView(world).isGrounded(caster),
        velocityX: transforms.velX[ti],
        minMoveSpeed: character.tuning.movement.minMoveSpeed,
        currentTick: currentTick,
        tickHz: tickHz,
      );
      final mi = world.movement.tryIndexOf(caster);
      final facingSign = mi != null && world.movement.facing[mi] == Facing.left
          ? -1
          : 1;
      final throwAim = bomb == null
          ? null
          : _bombAim.solve(
              world,
              source: caster,
              delivery: bomb,
              maxSpeed: projectile.speedUnitsPerSecond,
              gravityScale: intents.gravityScale[ii],
              fallbackFacing: facingSign < 0 ? Facing.left : Facing.right,
            );
      if (throwAim != null && mi != null) {
        world.movement.facing[mi] = throwAim.facing;
      }
      final sourceX =
          throwAim?.x ??
          transforms.posX[ti] +
              (offset == null
                  ? intents.sourceOffsetX[ii]
                  : offset.x * facingSign);
      final sourceY =
          throwAim?.y ??
          transforms.posY[ti] + (offset?.y ?? intents.sourceOffsetY[ii]);
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
          casterX: sourceX,
          casterY: sourceY,
          originOffset: bomb == null && offset == null
              ? intents.originOffset[ii]
              : 0,
          dirX: throwAim != null
              ? throwAim.velocityX
              : shots == 1
              ? intents.dirX[ii]
              : cos(shotAngle),
          dirY: throwAim != null
              ? throwAim.velocityY
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
          speedScale: throwAim == null
              ? intents.speedScaleBp[ii] / 10000.0
              : sqrt(
                      throwAim.velocityX * throwAim.velocityX +
                          throwAim.velocityY * throwAim.velocityY,
                    ) /
                    projectile.speedUnitsPerSecond,
        );
        if (bomb != null) {
          // Ballistic velocity owns the arc; keep the fuse sprite upright.
          final pi = world.projectile.indexOf(spawned);
          world.projectile.dirX[pi] = 1;
          world.projectile.dirY[pi] = 0;
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
