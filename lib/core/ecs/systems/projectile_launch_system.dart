import '../../projectiles/projectile_item_catalog.dart';
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
  ProjectileLaunchSystem({required this.projectileItems, required this.tickHz});

  final ProjectileItemCatalog projectileItems;
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
      final projectileItem = projectileItems.get(projectileId);

      spawnProjectileItemFromCaster(
        world,
        tickHz: tickHz,
        projectileId: projectileId,
        projectileItem: projectileItem,
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
        critChanceBp: intents.critChanceBp[ii],
        damageType: intents.damageType[ii],
        procs: intents.procs[ii],
        pierce: intents.pierce[ii],
        maxPierceHits: intents.maxPierceHits[ii],
        ballistic: intents.ballistic[ii],
        gravityScale: intents.gravityScale[ii],
        speedScale: intents.speedScaleBp[ii] / 10000.0,
      );
    }
  }

  void _invalidateIntent(ProjectileIntentStore intents, int index) {
    intents.tick[index] = -1;
    intents.commitTick[index] = -1;
  }
}
