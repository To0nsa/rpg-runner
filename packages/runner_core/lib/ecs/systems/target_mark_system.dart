import '../../abilities/ability_def.dart';
import '../../events/game_event.dart';
import '../stores/damage_queue_store.dart';
import '../world.dart';
import 'damage_middleware_system.dart';

/// Chooses the nearest live hostile in range, ties by entity ID.
int? findMarkTarget(
  EcsWorld world,
  int attacker,
  MarkHitDelivery delivery, {
  bool Function(double, double, double, double)? pathClear,
}) {
  final ti = world.transform.tryIndexOf(attacker),
      fi = world.faction.tryIndexOf(attacker);
  if (ti == null || fi == null) return null;
  final x = world.transform.posX[ti], y = world.transform.posY[ti];
  var bestDistance = delivery.range * delivery.range;
  int? best;
  for (var i = 0; i < world.health.denseEntities.length; i++) {
    final target = world.health.denseEntities[i];
    if (target == attacker ||
        world.health.hp[i] <= 0 ||
        world.deathState.has(target)) {
      continue;
    }
    final tf = world.faction.tryIndexOf(target),
        tt = world.transform.tryIndexOf(target);
    if (tf == null ||
        tt == null ||
        world.faction.faction[tf] == world.faction.faction[fi]) {
      continue;
    }
    final tx = world.transform.posX[tt], ty = world.transform.posY[tt];
    final distance = (tx - x) * (tx - x) + (ty - y) * (ty - y);
    if (distance > bestDistance ||
        (distance == bestDistance && best != null && target > best)) {
      continue;
    }
    if (pathClear != null && !pathClear(x, y, tx, ty)) continue;
    best = target;
    bestDistance = distance;
  }
  return best;
}

/// Only direct damage from the marking attacker receives the bonus.
class TargetMarkMiddleware extends DamageMiddleware {
  @override
  void apply(
    EcsWorld world,
    DamageQueueStore queue,
    int index,
    int currentTick,
  ) {
    final source = queue.sourceEntity[index];
    if (source == null) return;
    final marks = world.targetMark;
    final mi = marks.tryIndexOf(source);
    if (mi == null ||
        currentTick >= marks.expiresTick[mi] ||
        marks.target[mi] != queue.target[index]) {
      return;
    }
    if (queue.sourceKind[index] != DeathSourceKind.projectile &&
        queue.sourceMeleeAbilityId[index] == null) {
      return;
    }
    queue.amount100[index] =
        queue.amount100[index] * (10000 + marks.bonusBp[mi]) ~/ 10000;
  }
}
