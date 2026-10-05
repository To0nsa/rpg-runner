import 'dart:math' as math;

import '../../combat/projectile_pose_catalog.dart';
import '../../projectiles/projectile_id.dart';
import '../../projectiles/projectile_render_catalog.dart';
import '../../snapshots/enums.dart';
import '../world.dart';

/// Owns the shared flight-animation clock and anchor-relative damage silhouette.
final class ProjectilePoseSystem {
  const ProjectilePoseSystem({required this.tickHz});
  final int tickHz;

  void step(EcsWorld world, {required int currentTick}) {
    final store = world.projectile;
    for (var i = 0; i < store.denseEntities.length; i++) {
      final id = store.projectileId[i];
      if (id == ProjectileId.unknown || id == ProjectileId.poisonDart) continue;
      store.spawnTick[i] ??= currentTick;
      final age = math.max(0, currentTick - store.spawnTick[i]!);
      final render = const ProjectileRenderCatalog().get(id);
      final spawnStep = math.max(
        1,
        ((render.stepTimeSecondsByKey[AnimKey.spawn] ?? .1) * tickHz).round(),
      );
      final spawnTicks =
          (render.frameCountsByKey[AnimKey.spawn] ?? 0) * spawnStep;
      final anim = age < spawnTicks ? AnimKey.spawn : AnimKey.idle;
      final elapsed = age < spawnTicks ? age : age - spawnTicks;
      final step = math.max(
        1,
        ((render.stepTimeSecondsByKey[anim] ?? .1) * tickHz).round(),
      );
      store.anim[i] = anim;
      store.animFrame[i] = elapsed;
      final capsules = ProjectilePoseCatalog.frame(id, anim, elapsed ~/ step);
      store.combatCapsule[i] = capsules.isEmpty
          ? null
          : capsules.single.transformed(
              angle: math.atan2(store.dirY[i], store.dirX[i]),
            );
    }
  }
}
