import '../../combat/combat_geometry.dart';
import '../../abilities/ability_def.dart';
import '../../combat/damage_type.dart';
import '../../combat/knockback.dart';
import '../../combat/damage_credit.dart';
import '../../combat/faction.dart';
import '../../events/game_event.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

enum HitboxAttachment {
  /// Hitbox position is recalculated every tick from owner + offset.
  followOwner,

  /// Hitbox remains fixed at its spawn-world position.
  worldAnchor,
}

class HitboxDef {
  const HitboxDef({
    required this.owner,
    this.profile,
    this.frameStepTicks = 1,
    this.spawnTick = 0,
    this.abilityId,
    required this.faction,
    required this.damage100,
    this.critChanceBp = 0,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    this.knockback,
    this.hitPolicy = HitPolicy.oncePerTarget,
    this.sourceKind = DeathSourceKind.meleeHitbox,
    this.attachment = HitboxAttachment.followOwner,
    this.credit = DamageCredit.none,
    this.halfX = 0,
    this.halfY = 1,
    this.offsetX = 0,
    this.offsetY = 0,
    required this.dirX,
    required this.dirY,
  });

  final EntityId owner;
  final CombatStrikeProfile? profile;
  final int frameStepTicks;
  final int spawnTick;
  final AbilityKey? abilityId;
  final Faction faction;

  /// Fixed-point: 100 = 1.0
  final int damage100;

  /// Critical strike chance in basis points (100 = 1%).
  final int critChanceBp;
  final DamageType damageType;
  final List<WeaponProc> procs;
  final KnockbackSource? knockback;
  final HitPolicy hitPolicy;
  final DeathSourceKind sourceKind;
  final HitboxAttachment attachment;
  final DamageCredit credit;

  /// Unprofiled low-level capsule half-spine; rounded ends are additional.
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final double dirX;
  final double dirY;
}

/// Short-lived damage hitbox used by melee strikes and area effects.
///
/// These entities usually exist for only a few frames (strike windows).
/// They are queried by `HitboxDamageSystem`.
class HitboxStore extends SparseSet {
  final List<EntityId> owner = <EntityId>[];
  final List<CombatStrikeProfile?> profile = [];
  final List<int> frameStepTicks = [];
  final List<int> spawnTick = [];
  final List<List<CombatCapsule>?> capsules = [];
  final List<AbilityKey?> abilityId = <AbilityKey?>[];
  final List<Faction> faction = <Faction>[];

  /// Fixed-point: 100 = 1.0
  final List<int> damage100 = <int>[];
  final List<int> critChanceBp = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<KnockbackSource?> knockback = [];
  final List<HitPolicy> hitPolicy = <HitPolicy>[];
  final List<DeathSourceKind> sourceKind = <DeathSourceKind>[];
  final List<HitboxAttachment> attachment = <HitboxAttachment>[];
  final List<DamageCredit> credit = [];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<double> offsetX = <double>[];
  final List<double> offsetY = <double>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];

  void add(EntityId entity, HitboxDef def) {
    final i = addEntity(entity);
    owner[i] = def.owner;
    abilityId[i] = def.abilityId;
    faction[i] = def.faction;
    profile[i] = def.profile;
    capsules[i] = def.profile == null ? null : const [];
    frameStepTicks[i] = def.frameStepTicks;
    spawnTick[i] = def.spawnTick;
    damage100[i] = def.damage100;
    critChanceBp[i] = def.critChanceBp;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
    knockback[i] = def.knockback;
    hitPolicy[i] = def.hitPolicy;
    sourceKind[i] = def.sourceKind;
    attachment[i] = def.attachment;
    credit[i] = def.credit;
    halfX[i] = def.halfX;
    halfY[i] = def.halfY;
    offsetX[i] = def.offsetX;
    offsetY[i] = def.offsetY;
    dirX[i] = def.dirX;
    dirY[i] = def.dirY;
  }

  @override
  void onDenseAdded(int denseIndex) {
    owner.add(0);
    abilityId.add(null);
    faction.add(Faction.player);
    profile.add(null);
    frameStepTicks.add(1);
    spawnTick.add(0);
    capsules.add(null);
    damage100.add(0);
    critChanceBp.add(0);
    damageType.add(DamageType.physical);
    procs.add(const <WeaponProc>[]);
    knockback.add(null);
    hitPolicy.add(HitPolicy.oncePerTarget);
    sourceKind.add(DeathSourceKind.meleeHitbox);
    attachment.add(HitboxAttachment.followOwner);
    credit.add(DamageCredit.none);
    halfX.add(0);
    halfY.add(0);
    offsetX.add(0);
    offsetY.add(0);
    dirX.add(1.0);
    dirY.add(0.0);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    owner[removeIndex] = owner[lastIndex];
    abilityId[removeIndex] = abilityId[lastIndex];
    faction[removeIndex] = faction[lastIndex];
    profile[removeIndex] = profile[lastIndex];
    frameStepTicks[removeIndex] = frameStepTicks[lastIndex];
    spawnTick[removeIndex] = spawnTick[lastIndex];
    capsules[removeIndex] = capsules[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    critChanceBp[removeIndex] = critChanceBp[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    knockback[removeIndex] = knockback[lastIndex];
    hitPolicy[removeIndex] = hitPolicy[lastIndex];
    sourceKind[removeIndex] = sourceKind[lastIndex];
    attachment[removeIndex] = attachment[lastIndex];
    credit[removeIndex] = credit[lastIndex];
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    offsetX[removeIndex] = offsetX[lastIndex];
    offsetY[removeIndex] = offsetY[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];

    owner.removeLast();
    abilityId.removeLast();
    faction.removeLast();
    profile.removeLast();
    frameStepTicks.removeLast();
    spawnTick.removeLast();
    capsules.removeLast();
    damage100.removeLast();
    critChanceBp.removeLast();
    damageType.removeLast();
    procs.removeLast();
    knockback.removeLast();
    hitPolicy.removeLast();
    sourceKind.removeLast();
    attachment.removeLast();
    credit.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
    dirX.removeLast();
    dirY.removeLast();
  }
}
