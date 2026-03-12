import '../../combat/damage_type.dart';
import '../../combat/faction.dart';
import '../../weapons/weapon_proc.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class HitboxDef {
  const HitboxDef({
    required this.owner,
    required this.faction,
    required this.damage100,
    this.critChanceBp = 0,
    required this.damageType,
    this.procs = const <WeaponProc>[],
    required this.halfX,
    required this.halfY,
    required this.offsetX,
    required this.offsetY,
    required this.dirX,
    required this.dirY,
  });

  final EntityId owner;
  final Faction faction;

  /// Fixed-point: 100 = 1.0
  final int damage100;

  /// Critical strike chance in basis points (100 = 1%).
  final int critChanceBp;
  final DamageType damageType;
  final List<WeaponProc> procs;
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
  final List<Faction> faction = <Faction>[];

  /// Fixed-point: 100 = 1.0
  final List<int> damage100 = <int>[];
  final List<int> critChanceBp = <int>[];
  final List<DamageType> damageType = <DamageType>[];
  final List<List<WeaponProc>> procs = <List<WeaponProc>>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<double> offsetX = <double>[];
  final List<double> offsetY = <double>[];
  final List<double> dirX = <double>[];
  final List<double> dirY = <double>[];

  void add(EntityId entity, HitboxDef def) {
    final i = addEntity(entity);
    owner[i] = def.owner;
    faction[i] = def.faction;
    damage100[i] = def.damage100;
    critChanceBp[i] = def.critChanceBp;
    damageType[i] = def.damageType;
    procs[i] = def.procs;
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
    faction.add(Faction.player);
    damage100.add(0);
    critChanceBp.add(0);
    damageType.add(DamageType.physical);
    procs.add(const <WeaponProc>[]);
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
    faction[removeIndex] = faction[lastIndex];
    damage100[removeIndex] = damage100[lastIndex];
    critChanceBp[removeIndex] = critChanceBp[lastIndex];
    damageType[removeIndex] = damageType[lastIndex];
    procs[removeIndex] = procs[lastIndex];
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    offsetX[removeIndex] = offsetX[lastIndex];
    offsetY[removeIndex] = offsetY[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];

    owner.removeLast();
    faction.removeLast();
    damage100.removeLast();
    critChanceBp.removeLast();
    damageType.removeLast();
    procs.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
    dirX.removeLast();
    dirY.removeLast();
  }
}
