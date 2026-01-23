import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../projectiles/projectile_id.dart';
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
    required this.damage,
    required this.manaCost,
    required this.projectileId,
    required this.damageType,
    required this.statusProfileId,
    required this.originOffset,
    required this.cooldownTicks,
    required this.tick,
  });

  final SpellId spellId;
  final double damage;
  final double manaCost;
  final ProjectileId projectileId;
  final DamageType damageType;
  final StatusProfileId statusProfileId;
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
///
/// **Usage**: Persistent component. Intents are set via `set()` with a `tick` stamp.
/// Old intents are ignored if `tick` matches current game tick.
/// This avoids the overhead of adding/removing components every frame.
class CastIntentStore extends SparseSet {
  final List<SpellId> spellId = <SpellId>[];
  final List<double> damage = <double>[];
  final List<double> manaCost = <double>[];
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<StatusProfileId> statusProfileId = <StatusProfileId>[];
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
    damage[i] = def.damage;
    manaCost[i] = def.manaCost;
    projectileId[i] = def.projectileId;
    damageType[i] = def.damageType;
    statusProfileId[i] = def.statusProfileId;
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
    damage.add(0.0);
    manaCost.add(0.0);
    projectileId.add(ProjectileId.iceBolt);
    damageType.add(DamageType.ice);
    statusProfileId.add(StatusProfileId.none);
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
    damage[removeIndex] = damage[lastIndex];
    manaCost[removeIndex] = manaCost[lastIndex];
    projectileId[removeIndex] = projectileId[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    statusProfileId[removeIndex] = statusProfileId[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    fallbackDirX[removeIndex] = fallbackDirX[lastIndex];
    fallbackDirY[removeIndex] = fallbackDirY[lastIndex];
    originOffset[removeIndex] = originOffset[lastIndex];
    cooldownTicks[removeIndex] = cooldownTicks[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    spellId.removeLast();
    damage.removeLast();
    manaCost.removeLast();
    projectileId.removeLast();
    damageType.removeLast();
    statusProfileId.removeLast();
    dirX.removeLast();
    dirY.removeLast();
    fallbackDirX.removeLast();
    fallbackDirY.removeLast();
    originOffset.removeLast();
    cooldownTicks.removeLast();
    tick.removeLast();
  }
}
