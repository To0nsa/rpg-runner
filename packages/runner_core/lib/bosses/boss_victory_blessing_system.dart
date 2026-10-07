import '../ecs/collider_aabb_utils.dart';
import '../ecs/entity_id.dart';
import '../ecs/resource_restoration.dart';
import '../ecs/stores/restoration_item_store.dart';
import '../ecs/world.dart';
import '../events/game_event.dart';
import '../snapshots/boss_victory_blessing_snapshot.dart';
import '../snapshots/enums.dart';
import '../spell_impacts/spell_impact_id.dart';
import '../spell_impacts/spell_impact_render_catalog.dart';
import '../tuning/utils/anim_tuning.dart';
import '../track/chunk_pattern_tier.dart';
import '../util/vec2.dart';

/// Reusable victory reward configuration, independent of enemy identity.
final class BossVictoryBlessingDefinition {
  const BossVictoryBlessingDefinition({
    this.id = BossVictoryBlessingId.forestLadies,
    this.restorationBp = 6000,
    this.easyRestorationBp = 2000,
    this.effectId = SpellImpactId.holyBlessing,
  }) : assert(restorationBp >= 0 && restorationBp <= 10000),
       assert(easyRestorationBp >= 0 && easyRestorationBp <= 10000);
  final BossVictoryBlessingId id;

  /// Basis points of each current maximum in non-easy tiers, capped at the maximum.
  final int restorationBp;

  /// Basis points of each maximum in easy chunks: 20% leaves post-boss attrition.
  final int easyRestorationBp;
  final SpellImpactId effectId;
}

/// Applies completed arena rewards after this tick's fatal damage/death checks.
/// The arena proves death-strip completion; render callbacks cannot grant a reward.
final class BossVictoryBlessingSystem {
  BossVictoryBlessingSystem({
    required int tickHz,
    this.definition = const BossVictoryBlessingDefinition(),
  }) {
    final art = const SpellImpactRenderCatalog().get(definition.effectId);
    _durationTicks = ticksForKey(
      key: AnimKey.hit,
      frameCounts: art.frameCountsByKey,
      stepTimeSecondsByKey: art.stepTimeSecondsByKey,
      tickHz: tickHz,
    );
  }
  final BossVictoryBlessingDefinition definition;
  late final int _durationTicks;
  final Set<int> _processed = {};
  ({int occurrence, int restorationBp})? _pendingReward;
  BossVictoryBlessingSnapshot? _presentation;

  /// Queues the reward for the defeated occurrence's resolved authored tier.
  /// Difficulty belongs to that chunk, regardless of the player's later position.
  void request(int occurrence, ChunkPatternTier tier) {
    if (_processed.contains(occurrence)) return;
    assert(_pendingReward == null || _pendingReward!.occurrence == occurrence);
    _pendingReward = (
      occurrence: occurrence,
      restorationBp: tier == ChunkPatternTier.easy
          ? definition.easyRestorationBp
          : definition.restorationBp,
    );
  }

  void step(
    EcsWorld world, {
    required EntityId player,
    required int tick,
    required void Function(GameEvent) emit,
  }) {
    final reward = _pendingReward;
    if (reward == null) return;
    _pendingReward = null;
    if (!_processed.add(reward.occurrence)) return;
    final hi = world.health.tryIndexOf(player);
    final ti = world.transform.tryIndexOf(player);
    if (hi == null ||
        ti == null ||
        world.health.hp[hi] <= 0 ||
        world.deathState.has(player)) {
      return;
    }
    for (final stat in RestorationStat.values) {
      ResourceRestoration.restorePercent(
        world,
        entity: player,
        stat: stat,
        percentBp: reward.restorationBp,
      );
    }
    final ci = world.colliderAabb.tryIndexOf(player);
    final offset = ci == null
        ? Vec2.zero
        : Vec2(
            world.colliderAabb.offsetX[ci] * colliderFacingSign(world, player),
            world.colliderAabb.offsetY[ci] + world.colliderAabb.halfY[ci],
          );
    _presentation = BossVictoryBlessingSnapshot(
      id: definition.id,
      restorationBp: reward.restorationBp,
      startTick: tick,
      durationTicks: _durationTicks,
    );
    emit(
      SpellImpactEvent(
        tick: tick,
        impactId: definition.effectId,
        pos: Vec2(
          world.transform.posX[ti] + offset.x,
          world.transform.posY[ti] + offset.y,
        ),
        followEntityId: player,
        followOffset: offset,
      ),
    );
  }

  BossVictoryBlessingSnapshot? snapshot(int tick) {
    final value = _presentation;
    return value != null &&
            tick >= value.startTick &&
            tick - value.startTick < value.durationTicks
        ? value
        : null;
  }

  /// Drops feedback and pending grants without making an occurrence eligible again.
  void endRun() {
    _pendingReward = null;
    _presentation = null;
  }
}
