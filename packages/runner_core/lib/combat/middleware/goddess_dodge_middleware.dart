import '../../ecs/combat_eligibility.dart';
import '../../ecs/combat_target.dart';
import '../../ecs/entity_id.dart';
import '../../ecs/stores/damage_queue_store.dart';
import '../../ecs/stores/enemies/goddess_dodge_store.dart';
import '../../ecs/systems/damage_middleware_system.dart';
import '../../ecs/world.dart';
import '../../enemies/enemy_id.dart';
import '../../events/game_event.dart';
import '../../util/deterministic_rng.dart';

/// Counts direct player attacks until a seeded 4–6 attack dodge interval expires.
/// Misses, DoT, NPC attacks and protected hits never advance the cadence.
final class GoddessDodgeMiddleware implements DamageMiddleware {
  const GoddessDodgeMiddleware({required this.tryBeginDodge});

  /// The owning AI validates placement and commits the brief dodge action.
  final bool Function(EcsWorld, EntityId, EntityId, int) tryBeginDodge;

  @override
  void apply(
    EcsWorld world,
    DamageQueueStore queue,
    int index,
    int currentTick,
  ) {
    final boss = queue.target[index];
    final source = queue.sourceEntity[index];
    final ei = world.enemy.tryIndexOf(boss);
    if (ei == null ||
        world.enemy.enemyId[ei] != EnemyId.voidbornGoddess ||
        source == null ||
        !world.playerInput.has(source) ||
        !isLivingCombatActor(world, boss) ||
        !isLivingCombatActor(world, source) ||
        isCombatProtected(world, boss) ||
        world.arenaSuspension.has(boss)) {
      return;
    }
    final kind = queue.sourceKind[index];
    if (kind != DeathSourceKind.meleeHitbox &&
        kind != DeathSourceKind.projectile &&
        kind != DeathSourceKind.spellImpact) {
      return;
    }
    final combo = queue.comboHit[index];
    final key = combo?.source == source ? (source, combo!.activation) : null;
    final state = world.goddessDodge;
    final i = state.tryIndexOf(boss) ?? state.addEntity(boss);
    if (key != null && state.comboDodged[i].containsKey(key)) {
      if (state.comboDodged[i][key]!) queue.cancel(index);
      return;
    }
    final ii = world.invulnerability.tryIndexOf(boss);
    if (ii != null && !world.invulnerability.allowsHit(ii, combo)) return;
    final tactic = world.goddessTactics.tryIndexOf(boss);
    if (state.executeTick[i] >= 0 ||
        world.goddessBarrage.has(boss) ||
        (tactic != null &&
            world.goddessTactics.states[tactic].scriptedTransition) ||
        world.controlLock.isStunned(boss, currentTick)) {
      return;
    }
    if (key != null) state.comboDodged[i][key] = false;
    if (state.attackInterval[i] == 0) _rollInterval(state, i);
    if (state.attacks[i] < state.attackInterval[i] - 1) {
      state.attacks[i]++;
      return;
    }
    // Blocked placement keeps this interval charged without rerolling it.
    if (!tryBeginDodge(world, boss, source, currentTick)) return;
    state.attacks[i] = 0;
    _rollInterval(state, i);
    if (key != null) state.comboDodged[i][key] = true;
    queue.cancel(index);
  }

  void _rollInterval(GoddessDodgeStore state, int i) {
    final roll = nextUint32(state.rngState[i]);
    state.rngState[i] = roll;
    state.attackInterval[i] = 4 + roll % 3;
  }
}
