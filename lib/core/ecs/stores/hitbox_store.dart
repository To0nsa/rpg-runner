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
  });

  final EntityId owner;
  final Faction faction;
  final double damage;
  final double halfX;
  final double halfY;
  final double offsetX;
  final double offsetY;
}

/// Short-lived damage hitbox used by melee attacks and area effects.
class HitboxStore extends SparseSet {
  final List<EntityId> owner = <EntityId>[];
  final List<Faction> faction = <Faction>[];
  final List<double> damage = <double>[];
  final List<double> halfX = <double>[];
  final List<double> halfY = <double>[];
  final List<double> offsetX = <double>[];
  final List<double> offsetY = <double>[];

  void add(EntityId entity, HitboxDef def) {
    final i = addEntity(entity);
    owner[i] = def.owner;
    faction[i] = def.faction;
    damage[i] = def.damage;
    halfX[i] = def.halfX;
    halfY[i] = def.halfY;
    offsetX[i] = def.offsetX;
    offsetY[i] = def.offsetY;
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

    owner.removeLast();
    faction.removeLast();
    damage.removeLast();
    halfX.removeLast();
    halfY.removeLast();
    offsetX.removeLast();
    offsetY.removeLast();
  }
}

