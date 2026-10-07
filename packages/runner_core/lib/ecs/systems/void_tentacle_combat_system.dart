import '../../enemies/enemy_id.dart';
import '../world.dart';

/// Planted tentacles use ordinary melee targeting and damage, without pursuit.
final class VoidTentacleCombatSystem {
  const VoidTentacleCombatSystem();

  /// Overrides engagement before locomotion, retaining the terrain-owned body.
  void step(EcsWorld world) {
    for (final entity in world.bossSummon.denseEntities) {
      final ei = world.enemy.tryIndexOf(entity);
      if (ei == null || world.enemy.enemyId[ei] != EnemyId.voidTentacle) {
        continue;
      }
      final ni = world.navIntent.tryIndexOf(entity);
      if (ni != null) world.navIntent.hasPlan[ni] = false;
      final ii = world.engagementIntent.tryIndexOf(entity);
      if (ii != null) world.engagementIntent.speedScale[ii] = 0;
    }
  }
}
