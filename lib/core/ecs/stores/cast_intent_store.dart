import '../../spells/spell_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class CastIntentDef {
  const CastIntentDef({
    required this.spellId,
    required this.dirX,
    required this.dirY,
    required this.fallbackDirX,
    required this.fallbackDirY,
    required this.originOffset,
    required this.cooldownTicks,
    required this.tick,
  });

  final SpellId spellId;
  final double dirX;
  final double dirY;
  final double fallbackDirX;
  final double fallbackDirY;
  final double originOffset;
  final int cooldownTicks;

  /// Tick stamp for this intent.
  ///
  /// Use `-1` for "no intent". An intent is valid only when `tick == currentTick`.
  final int tick;
}

/// Per-entity "cast a spell this tick" intent.
///
/// This is written by player/enemy intent writers and consumed by `SpellCastSystem`.
class CastIntentStore extends SparseSet {
  final List<SpellId> spellId = <SpellId>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<double> fallbackDirX = <double>[];
  final List<double> fallbackDirY = <double>[];
  final List<double> originOffset = <double>[];
  final List<int> cooldownTicks = <int>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, CastIntentDef def) {
    assert(
      has(entity),
      'CastIntentStore.set called for entity without CastIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    spellId[i] = def.spellId;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    fallbackDirX[i] = def.fallbackDirX;
    fallbackDirY[i] = def.fallbackDirY;
    originOffset[i] = def.originOffset;
    cooldownTicks[i] = def.cooldownTicks;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    spellId.add(SpellId.iceBolt);
    dirX.add(0.0);
    dirY.add(0.0);
    fallbackDirX.add(1.0);
    fallbackDirY.add(0.0);
    originOffset.add(0.0);
    cooldownTicks.add(0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    spellId[removeIndex] = spellId[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    fallbackDirX[removeIndex] = fallbackDirX[lastIndex];
    fallbackDirY[removeIndex] = fallbackDirY[lastIndex];
    originOffset[removeIndex] = originOffset[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    spellId.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    fallbackDirX.removeLast();
    fallbackDirY.removeLast();
    originOffset.removeLast();
    cooldownTicks.removeLast();
    tick.removeLast();
  }
}
