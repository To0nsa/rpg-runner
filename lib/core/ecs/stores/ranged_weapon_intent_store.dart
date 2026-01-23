import '../../weapons/ranged_weapon_id.dart';
import '../../combat/damage_type.dart';
import '../../combat/status/status.dart';
import '../../projectiles/projectile_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class RangedWeaponIntentDef {
  const RangedWeaponIntentDef({
    required this.weaponId, // Kept for debugging/legacy
    required this.damage100,
    required this.staminaCost,
    required this.rechargeTicks,
    required this.projectileId,
    required this.damageType,
    required this.statusProfileId,
    required this.ballistic,
    required this.gravityScale,
    required this.dirX,
    required this.dirY,
    required this.fallbackDirX,
    required this.fallbackDirY,
    required this.originOffset,
    required this.tick,
  });

  final RangedWeaponId weaponId;
  final int damage100;
  final double staminaCost;
  final int rechargeTicks;
  final ProjectileId projectileId;
  final DamageType damageType;
  final StatusProfileId statusProfileId;
  final bool ballistic;
  final double gravityScale;

  final double dirX;
  final double dirY;
  final double fallbackDirX;
  final double fallbackDirY;
  final double originOffset;

  /// Tick stamp for this intent.
  ///
  /// Use `-1` for "no intent". An intent is valid only when `tick == currentTick`.
  final int tick;
}

/// Per-entity "fire a ranged weapon this tick" intent.
///
/// Written by player input and consumed by `RangedWeaponSystem`.
class RangedWeaponIntentStore extends SparseSet {
  final List<RangedWeaponId> weaponId = <RangedWeaponId>[];
  final List<int> damage100 = <int>[];
  final List<double> staminaCost = <double>[];
  final List<int> rechargeTicks = <int>[];
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<StatusProfileId> statusProfileId = <StatusProfileId>[];
  final List<bool> ballistic = <bool>[];
  final List<double> gravityScale = <double>[];
  
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];
  final List<double> fallbackDirX = <double>[];
  final List<double> fallbackDirY = <double>[];
  final List<double> originOffset = <double>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  void set(EntityId entity, RangedWeaponIntentDef def) {
    assert(
      has(entity),
      'RangedWeaponIntentStore.set called for entity without RangedWeaponIntentStore; add the component at spawn time.',
    );
    final i = indexOf(entity);
    weaponId[i] = def.weaponId;
    damage100[i] = def.damage100;
    staminaCost[i] = def.staminaCost;
    rechargeTicks[i] = def.rechargeTicks;
    projectileId[i] = def.projectileId;
    damageType[i] = def.damageType;
    statusProfileId[i] = def.statusProfileId;
    ballistic[i] = def.ballistic;
    gravityScale[i] = def.gravityScale;
    
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
    fallbackDirX[i] = def.fallbackDirX;
    fallbackDirY[i] = def.fallbackDirY;
    originOffset[i] = def.originOffset;
    tick[i] = def.tick;
  }

  @override
  void onDenseAdded(int denseIndex) {
    weaponId.add(RangedWeaponId.throwingKnife);
    damage100.add(0);
    staminaCost.add(0.0);
    rechargeTicks.add(0);
    projectileId.add(ProjectileId.throwingKnife); // Default matching weaponId
    damageType.add(DamageType.physical);
    statusProfileId.add(StatusProfileId.none);
    ballistic.add(true);
    gravityScale.add(1.0);
    
    dirX.add(0.0);
    dirY.add(0.0);
    fallbackDirX.add(1.0);
    fallbackDirY.add(0.0);
    originOffset.add(0.0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    weaponId[removeIndex] = weaponId[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    staminaCost[removeIndex] = staminaCost[lastIndex];
    rechargeTicks[removeIndex] = rechargeTicks[lastIndex];
    projectileId[removeIndex] = projectileId[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    statusProfileId[removeIndex] = statusProfileId[lastIndex];
    ballistic[removeIndex] = ballistic[lastIndex];
    gravityScale[removeIndex] = gravityScale[lastIndex];
    
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];
    fallbackDirX[removeIndex] = fallbackDirX[lastIndex];
    fallbackDirY[removeIndex] = fallbackDirY[lastIndex];
    originOffset[removeIndex] = originOffset[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    weaponId.removeLast();
    damage100.removeLast();
    staminaCost.removeLast();
    rechargeTicks.removeLast();
    projectileId.removeLast();
    damageType.removeLast();
    statusProfileId.removeLast();
    ballistic.removeLast();
    gravityScale.removeLast();

    dirX.removeLast();
    dirY.removeLast();
    fallbackDirX.removeLast();
    fallbackDirY.removeLast();
    originOffset.removeLast();
    tick.removeLast();
  }
}

