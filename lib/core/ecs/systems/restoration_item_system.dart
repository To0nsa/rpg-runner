import '../hit/aabb_hit_utils.dart';
import '../entity_id.dart';
import '../world.dart';
import '../stores/restoration_item_store.dart';
import '../../tuning/restoration_item_tuning.dart';

class RestorationItemSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  void step(
    EcsWorld world, {
    required EntityId player,
    required double cameraLeft,
    required RestorationItemTuning tuning,
  }) {
    final items = world.restorationItem;
    if (items.denseEntities.isEmpty) return;

    final playerTi = world.transform.tryIndexOf(player);
    final playerAi = world.colliderAabb.tryIndexOf(player);

    _toDespawn.clear();

    final despawnLimit = cameraLeft - tuning.despawnBehindCameraMargin;
    for (var ii = 0; ii < items.denseEntities.length; ii += 1) {
      final e = items.denseEntities[ii];
      final ti = world.transform.tryIndexOf(e);
      final ai = world.colliderAabb.tryIndexOf(e);
      if (ti == null || ai == null) continue;

      final centerX = world.transform.posX[ti] + world.colliderAabb.offsetX[ai];
      if (centerX < despawnLimit) {
        _toDespawn.add(e);
        continue;
      }

      if (playerTi != null && playerAi != null) {
        final overlaps = aabbOverlapsWorldColliders(
          world,
          aTransformIndex: ti,
          aAabbIndex: ai,
          bTransformIndex: playerTi,
          bAabbIndex: playerAi,
        );
        if (overlaps) {
          _applyRestore(
            world,
            player: player,
            stat: items.stat[ii],
            percent: tuning.restorePercent,
          );
          _toDespawn.add(e);
        }
      }
    }

    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }

  void _applyRestore(
    EcsWorld world, {
    required EntityId player,
    required RestorationStat stat,
    required double percent,
  }) {
    switch (stat) {
      case RestorationStat.health:
        final hi = world.health.tryIndexOf(player);
        if (hi == null) return;
        final maxHp = world.health.hpMax[hi];
        if (maxHp <= 0) return;
        final restored = world.health.hp[hi] + maxHp * percent;
        world.health.hp[hi] = restored > maxHp ? maxHp : restored;
      case RestorationStat.mana:
        final mi = world.mana.tryIndexOf(player);
        if (mi == null) return;
        final maxMana = world.mana.manaMax[mi];
        if (maxMana <= 0) return;
        final restored = world.mana.mana[mi] + maxMana * percent;
        world.mana.mana[mi] = restored > maxMana ? maxMana : restored;
      case RestorationStat.stamina:
        final si = world.stamina.tryIndexOf(player);
        if (si == null) return;
        final maxStamina = world.stamina.staminaMax[si];
        if (maxStamina <= 0) return;
        final restored = world.stamina.stamina[si] + maxStamina * percent;
        world.stamina.stamina[si] =
            restored > maxStamina ? maxStamina : restored;
    }
  }
}
