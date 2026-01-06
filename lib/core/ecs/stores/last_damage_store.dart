import '../../enemies/enemy_id.dart';
import '../../events/game_event.dart';
import '../../projectiles/projectile_id.dart';
import '../../spells/spell_id.dart';
import '../entity_id.dart';
import '../sparse_set.dart';

/// Per-entity record of the last applied damage metadata.
///
/// Used to populate the "Game Over" screen with cause of death.
class LastDamageStore extends SparseSet {
  final List<DeathSourceKind> kind = <DeathSourceKind>[];
  final List<EnemyId> enemyId = <EnemyId>[];
  final List<bool> hasEnemyId = <bool>[];
  final List<ProjectileId> projectileId = <ProjectileId>[];
  final List<bool> hasProjectileId = <bool>[];
  final List<SpellId> spellId = <SpellId>[];
  final List<bool> hasSpellId = <bool>[];
  final List<double> amount = <double>[];
  final List<int> tick = <int>[];

  void add(EntityId entity) {
    addEntity(entity);
  }

  @override
  void onDenseAdded(int denseIndex) {
    kind.add(DeathSourceKind.unknown);
    enemyId.add(EnemyId.flyingEnemy);
    hasEnemyId.add(false);
    projectileId.add(ProjectileId.iceBolt);
    hasProjectileId.add(false);
    spellId.add(SpellId.iceBolt);
    hasSpellId.add(false);
    amount.add(0.0);
    tick.add(-1);
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    kind[removeIndex] = kind[lastIndex];
    enemyId[removeIndex] = enemyId[lastIndex];
    hasEnemyId[removeIndex] = hasEnemyId[lastIndex];
    projectileId[removeIndex] = projectileId[lastIndex];
    hasProjectileId[removeIndex] = hasProjectileId[lastIndex];
    spellId[removeIndex] = spellId[lastIndex];
    hasSpellId[removeIndex] = hasSpellId[lastIndex];
    amount[removeIndex] = amount[lastIndex];
    tick[removeIndex] = tick[lastIndex];

    kind.removeLast();
    enemyId.removeLast();
    hasEnemyId.removeLast();
    projectileId.removeLast();
    hasProjectileId.removeLast();
    spellId.removeLast();
    hasSpellId.removeLast();
    amount.removeLast();
    tick.removeLast();
  }
}
