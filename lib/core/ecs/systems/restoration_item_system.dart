import 'dart:math' as math;
import '../entity_id.dart';
import '../world.dart';
import '../stores/restoration_item_store.dart';
import '../../tuning/restoration_item_tuning.dart';

/// Handles the lifecycle and collision of restoration pickups (Health/Mana/Stamina potions).
///
/// **Responsibilities**:
/// - Despawns items that fall too far behind the camera.
/// - Checks for collision with the Player.
/// - Applies restoration effects and despawns on pickup.
class RestorationItemSystem {
  final List<EntityId> _toDespawn = <EntityId>[];

  /// Executes the system logic for a single frame.
  ///
  /// - [player]: The valid [EntityId] of the local player character.
  /// - [cameraLeft]: The X coordinate of the camera's left edge (used for culling).
  /// - [tuning]: Configuration values for pickup ranges and restore amounts.
  void step(
    EcsWorld world, {
    required EntityId player,
    required double cameraLeft,
    required RestorationItemTuning tuning,
  }) {
    final items = world.restorationItem;
    // Early exit if no items exist to process.
    if (items.denseEntities.isEmpty) return;
    
    _toDespawn.clear();
    final despawnLimit = cameraLeft - tuning.despawnBehindCameraMargin;

    // -- Resolve Player AABB (Optimization) --
    // We cache the player's world-space bounds once per frame.
    final transforms = world.transform;
    final colliders = world.colliderAabb;

    final pTi = transforms.tryIndexOf(player);
    final pCi = colliders.tryIndexOf(player);
    
    // Bounds: Min/Max X/Y
    double pMinX = 0, pMaxX = 0, pMinY = 0, pMaxY = 0;
    bool playerActive = false;

    if (pTi != null && pCi != null) {
      playerActive = true;
      final cx = transforms.posX[pTi] + colliders.offsetX[pCi];
      final cy = transforms.posY[pTi] + colliders.offsetY[pCi];
      final hx = colliders.halfX[pCi];
      final hy = colliders.halfY[pCi];
      pMinX = cx - hx;
      pMaxX = cx + hx;
      pMinY = cy - hy;
      pMaxY = cy + hy;
    }

    // -- Iterate Items --
    final count = items.denseEntities.length;
    for (var ii = 0; ii < count; ii += 1) {
      final e = items.denseEntities[ii];
      
      final ti = transforms.tryIndexOf(e);
      // Skip items that are missing spatial components (malformed entities).
      if (ti == null) continue;
      
      final ci = colliders.tryIndexOf(e);
      if (ci == null) continue;

      final cx = transforms.posX[ti] + colliders.offsetX[ci];
      
      // 1. Despawn Logic (Garbage Collection)
      if (cx < despawnLimit) {
        _toDespawn.add(e);
        continue;
      }

      // 2. Collision Check (Pickup)
      if (playerActive) {
        final cy = transforms.posY[ti] + colliders.offsetY[ci];
        final hx = colliders.halfX[ci];
        final hy = colliders.halfY[ci];

        // AABB Overlap Logic:
        final overlaps = (cx - hx) < pMaxX && 
                         (cx + hx) > pMinX && 
                         (cy - hy) < pMaxY && 
                         (cy + hy) > pMinY;

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

    // Process all despawns in batch at the end of the frame.
    for (final e in _toDespawn) {
      world.destroyEntity(e);
    }
  }

  /// RESTORES a specific stat on the target [player].
  ///
  /// - [percent]: Percentage of MAX value to restore (0.0 to 1.0).
  /// - Scales based on the player's Max HP/Mana/Stamina.
  /// - Clamps to Max value (prevents overhealing).
  void _applyRestore(
    EcsWorld world, {
    required EntityId player,
    required RestorationStat stat,
    required double percent,
  }) {
    // Note: We use min/max checks to ensure we don't overheal or divide by zero.
    switch (stat) {
      case RestorationStat.health:
        final index = world.health.tryIndexOf(player);
        if (index != null) {
          final max = world.health.hpMax[index];
          if (max > 0) {
            world.health.hp[index] = math.min(max, world.health.hp[index] + max * percent);
          }
        }
      case RestorationStat.mana:
        final index = world.mana.tryIndexOf(player);
        if (index != null) {
          final max = world.mana.manaMax[index];
          if (max > 0) {
            world.mana.mana[index] = math.min(max, world.mana.mana[index] + max * percent);
          }
        }
      case RestorationStat.stamina:
        final index = world.stamina.tryIndexOf(player);
        if (index != null) {
          final max = world.stamina.staminaMax[index];
          if (max > 0) {
            world.stamina.stamina[index] = math.min(max, world.stamina.stamina[index] + max * percent);
          }
        }
    }
  }
}
