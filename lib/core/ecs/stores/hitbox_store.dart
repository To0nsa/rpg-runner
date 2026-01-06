import '../../combat/faction.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

class HitboxDef {
  const HitboxDef({
    required this.owner,
    required this.faction,
    required this.damage,
    required this.halfX,
    required this.halfY,
    required this.offsetX,
    required this.offsetY,
    required this.dirX,
    required this.dirY,
  });

  final EntityId owner;
  final Faction faction;
  final double damage;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
  final double dirX;
  final double dirY;
}

/// Short-lived damage hitbox used by melee attacks and area effects.
///
/// These entities usually exist for only a few frames (attack windows).
/// They are queried by `HitboxDamageSystem`.
class HitboxStore extends SparseSet {
  final List<EntityId> owner = <EntityId>[];
  final List<Faction> faction = <Faction>[];
  final List<double> damage = <double>[];
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
    damage[i] = def.damage;
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
    damage.add(0);
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
    damage[removeIndex] = damage[lastIndex];
    halfX[removeIndex] = halfX[lastIndex];
    halfY[removeIndex] = halfY[lastIndex];
    offsetX[removeIndex] = offsetX[lastIndex];
    offsetY[removeIndex] = offsetY[lastIndex];
    dirX[removeIndex] = dirX[lastIndex];
    dirY[removeIndex] = dirY[lastIndex];

    owner.removeLast();
    faction.removeLast();
    damage.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
    dirX.removeLast();
    dirY.removeLast();
  }
}
