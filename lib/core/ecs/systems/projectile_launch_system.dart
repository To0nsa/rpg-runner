import '../../projectiles/projectile_catalog.dart';
import '../../projectiles/spawn_projectile_item.dart';
import '../stores/projectile_intent_store.dart';
import '../stores/transform_store.dart';
import '../world.dart';

/// Executes [ProjectileIntentStore] intents by spawning projectiles.
///
/// **Execution Only**:
/// - Reads committed intents (`tick == currentTick`).
/// - Spawns projectile entities.
/// - Does **not** deduct resources or start cooldowns (handled by Activation).
class ProjectileLaunchSystem {
  ProjectileLaunchSystem({required this.projectiles});

  final ProjectileCatalogDerived projectiles;

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
