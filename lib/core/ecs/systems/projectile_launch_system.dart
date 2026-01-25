import '../../snapshots/enums.dart';
import '../../util/fixed_math.dart';
import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/spawn_projectile_item.dart';
import '../stores/projectile_intent_store.dart';
import '../world.dart';

/// Executes [ProjectileIntentStore] intents by spawning projectiles and managing resources.
///
/// **Responsibilities**:
/// - Consumes projectile intents stamped with the `currentTick`.
/// - Validates cooldowns and resource costs (mana/stamina).
/// - Spawns projectile entities via [spawnProjectileItemFromCaster].
/// - Starts unified projectile cooldown and ActiveAbility state on commit.
class ProjectileLaunchSystem {
  ProjectileLaunchSystem({required this.projectiles});

  final ProjectileCatalogDerived projectiles;

  void step(EcsWorld world, {required int currentTick}) {
    final intents = world.projectileIntent;
    if (intents.denseEntities.isEmpty) return;

    final transforms = world.transform;
    final cooldowns = world.cooldown;
    final manas = world.mana;
    final staminas = world.stamina;
    final factions = world.faction;

    final count = intents.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final caster = intents.denseEntities[ii];
      final commitTick = intents.commitTick[ii];
      final executeTick = intents.tick[ii];

      final ti = transforms.tryIndexOf(caster);
      if (ti == null) {
        _invalidateIntent(intents, ii);
        continue;
      }

      if (commitTick == currentTick) {
        if (world.controlLock.isStunned(caster, currentTick)) {
          _invalidateIntent(intents, ii);
          continue;
        }

        final ci = cooldowns.tryIndexOf(caster);
        if (ci == null) {
          _invalidateIntent(intents, ii);
          continue;
        }
        if (cooldowns.projectileCooldownTicksLeft[ci] > 0) {
          _invalidateIntent(intents, ii);
          continue;
        }

        int? mi;
        int currentMana = 0;
        final manaCost = intents.manaCost100[ii];
        if (manaCost > 0) {
          mi = manas.tryIndexOf(caster);
          if (mi == null) {
            _invalidateIntent(intents, ii);
            continue;
          }
          currentMana = manas.mana[mi];
          if (currentMana < manaCost) {
            _invalidateIntent(intents, ii);
            continue;
          }
        }

        int? si;
        int currentStamina = 0;
        final staminaCost = intents.staminaCost100[ii];
        if (staminaCost > 0) {
          si = staminas.tryIndexOf(caster);
          if (si == null) {
            _invalidateIntent(intents, ii);
            continue;
          }
          currentStamina = staminas.stamina[si];
          if (currentStamina < staminaCost) {
            _invalidateIntent(intents, ii);
            continue;
          }
        }

        if (mi != null) {
          final max = manas.manaMax[mi];
          manas.mana[mi] = clampInt(currentMana - manaCost, 0, max);
        }
        if (si != null) {
          final max = staminas.staminaMax[si];
          staminas.stamina[si] = clampInt(
            currentStamina - staminaCost,
            0,
            max,
          );
        }

        cooldowns.projectileCooldownTicksLeft[ci] = intents.cooldownTicks[ii];

        final dirX = intents.dirX[ii];
        final fallbackX = intents.fallbackDirX[ii];
        final facingDir =
            (dirX.abs() > 1e-6 ? dirX : fallbackX) >= 0
                ? Facing.right
                : Facing.left;

        world.activeAbility.set(
          caster,
          id: intents.abilityId[ii],
          slot: intents.slot[ii],
          commitTick: currentTick,
          windupTicks: intents.windupTicks[ii],
          activeTicks: intents.activeTicks[ii],
          recoveryTicks: intents.recoveryTicks[ii],
          facingDir: facingDir,
        );
      }

      final fi = factions.tryIndexOf(caster);
      if (fi == null) continue;

      if (executeTick != currentTick) continue;

      _invalidateIntent(intents, ii);

      spawnProjectileItemFromCaster(
        world,
        projectiles: projectiles,
        projectileItemId: intents.projectileItemId[ii],
        projectileId: intents.projectileId[ii],
        faction: factions.faction[fi],
        owner: caster,
        casterX: transforms.posX[ti],
        casterY: transforms.posY[ti],
        originOffset: intents.originOffset[ii],
        dirX: intents.dirX[ii],
        dirY: intents.dirY[ii],
        fallbackDirX: intents.fallbackDirX[ii],
        fallbackDirY: intents.fallbackDirY[ii],
        damage100: intents.damage100[ii],
        damageType: intents.damageType[ii],
        statusProfileId: intents.statusProfileId[ii],
        procs: intents.procs[ii],
        ballistic: intents.ballistic[ii],
        gravityScale: intents.gravityScale[ii],
      );
    }
  }

  void _invalidateIntent(ProjectileIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
