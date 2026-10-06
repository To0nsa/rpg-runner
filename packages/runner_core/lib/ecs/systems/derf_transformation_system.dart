import '../../combat/control_lock.dart';
import '../../enemies/enemy_catalog.dart';
import '../../enemies/enemy_id.dart';
import '../../snapshots/enums.dart';
import '../../tuning/utils/anim_tuning.dart';
import '../collider_aabb_utils.dart';
import '../hit/aabb_hit_utils.dart';
import '../stores/enemies/derf_phase_store.dart';
import '../world.dart';
import 'ability_interrupt.dart';

/// Awakens Derf once his body enters the authoritative Core camera rectangle.
///
/// Runs after lock refresh before AI and again after camera movement so the
/// first visible snapshot already transforms. One-tick locks expire naturally
/// when transformation ends, preserving longer locks from other sources.
class DerfTransformationSystem {
  DerfTransformationSystem({
    required int tickHz,
    EnemyCatalog enemyCatalog = const EnemyCatalog(),
  }) : transformationTicks = ticksForKey(
         key: AnimKey.transform,
         frameCounts: enemyCatalog
             .get(EnemyId.derf)
             .renderAnim
             .frameCountsByKey,
         stepTimeSecondsByKey: enemyCatalog
             .get(EnemyId.derf)
             .renderAnim
             .stepTimeSecondsByKey,
         tickHz: tickHz,
       );

  /// Quantized strip duration in simulation ticks, shared with frame sampling.
  final int transformationTicks;

  void step(
    EcsWorld world, {
    required int currentTick,
    required double cameraLeft,
    required double cameraTop,
    required double cameraRight,
    required double cameraBottom,
  }) {
    final phases = world.derfPhase;
    for (var i = 0; i < phases.denseEntities.length; i++) {
      final entity = phases.denseEntities[i];
      if (world.deathState.has(entity) ||
          world.health.hp[world.health.indexOf(entity)] <= 0 ||
          phases.phase[i] == DerfPhase.twisted) {
        continue;
      }
      if (phases.phase[i] == DerfPhase.caster) {
        final ti = world.transform.indexOf(entity);
        final ci = world.colliderAabb.indexOf(entity);
        final x = colliderCenterX(
          world,
          entity: entity,
          transformIndex: ti,
          colliderIndex: ci,
        );
        final y = colliderCenterY(world, transformIndex: ti, colliderIndex: ci);
        if (aabbOverlapsMinMax(
          aMinX: x - world.colliderAabb.halfX[ci],
          aMaxX: x + world.colliderAabb.halfX[ci],
          aMinY: y - world.colliderAabb.halfY[ci],
          aMaxY: y + world.colliderAabb.halfY[ci],
          bMinX: cameraLeft,
          bMaxX: cameraRight,
          bMinY: cameraTop,
          bMaxY: cameraBottom,
        )) {
          phases.phase[i] = DerfPhase.transforming;
          phases.transformationStartTick[i] = currentTick;
          AbilityInterrupt.clearActiveAndTransient(
            world,
            entity: entity,
            startDeferredCooldown: false,
          );
        }
      }
      if (phases.phase[i] == DerfPhase.transforming &&
          currentTick - phases.transformationStartTick[i] >=
              transformationTicks) {
        phases.phase[i] = DerfPhase.twisted;
        continue;
      }
      final mask = phases.phase[i] == DerfPhase.caster
          ? LockFlag.allMovement | LockFlag.nav | LockFlag.strike
          : LockFlag.allExceptStun;
      world.controlLock.addLock(entity, mask, 1, currentTick);
    }
  }
}
