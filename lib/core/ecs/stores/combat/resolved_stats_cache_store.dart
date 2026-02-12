import '../../../accessories/accessory_id.dart';
import '../../../projectiles/projectile_item_id.dart';
import '../../../spells/spell_book_id.dart';
import '../../../stats/character_stats_resolver.dart';
import '../../../stats/gear_stat_bonuses.dart';
import '../../../weapons/weapon_id.dart';
import '../../entity_id.dart';
import '../../sparse_set.dart';

/// Cached per-entity resolved stats derived from equipped loadout.
///
/// This store mirrors only the gear-relevant loadout fields used by
/// [CharacterStatsResolver]. Systems can compare against live loadout values and
/// reuse [stats] when unchanged.
class ResolvedStatsCacheStore extends SparseSet {
  final List<int> mask = <int>[];
  final List<WeaponId> mainWeaponId = <WeaponId>[];
  final List<WeaponId> offhandWeaponId = <WeaponId>[];
  final List<ProjectileItemId> projectileItemId = <ProjectileItemId>[];
  final List<SpellBookId> spellBookId = <SpellBookId>[];
  final List<AccessoryId> accessoryId = <AccessoryId>[];
  final List<ResolvedCharacterStats> stats = <ResolvedCharacterStats>[];

  void setForEntity(
    EntityId entity, {
    required int mask,
    required WeaponId mainWeaponId,
    required WeaponId offhandWeaponId,
    required ProjectileItemId projectileItemId,
    required SpellBookId spellBookId,
    required AccessoryId accessoryId,
    required ResolvedCharacterStats stats,
  }) {
    final i = addEntity(entity);
    this.mask[i] = mask;
    this.mainWeaponId[i] = mainWeaponId;
    this.offhandWeaponId[i] = offhandWeaponId;
    this.projectileItemId[i] = projectileItemId;
    this.spellBookId[i] = spellBookId;
    this.accessoryId[i] = accessoryId;
    this.stats[i] = stats;
  }

  bool matchesLoadout({
    required int cacheIndex,
    required int mask,
    required WeaponId mainWeaponId,
    required WeaponId offhandWeaponId,
    required ProjectileItemId projectileItemId,
    required SpellBookId spellBookId,
    required AccessoryId accessoryId,
  }) {
    return this.mask[cacheIndex] == mask &&
        this.mainWeaponId[cacheIndex] == mainWeaponId &&
        this.offhandWeaponId[cacheIndex] == offhandWeaponId &&
        this.projectileItemId[cacheIndex] == projectileItemId &&
        this.spellBookId[cacheIndex] == spellBookId &&
        this.accessoryId[cacheIndex] == accessoryId;
  }

  @override
  void onDenseAdded(int denseIndex) {
    mask.add(0);
    mainWeaponId.add(WeaponId.woodenSword);
    offhandWeaponId.add(WeaponId.woodenShield);
    projectileItemId.add(ProjectileItemId.throwingKnife);
    spellBookId.add(SpellBookId.basicSpellBook);
    accessoryId.add(AccessoryId.speedBoots);
    stats.add(const ResolvedCharacterStats(bonuses: GearStatBonuses.zero));
  }

  @override
  void onSwapRemove(int removeIndex, int lastIndex) {
    mask[removeIndex] = mask[lastIndex];
    mainWeaponId[removeIndex] = mainWeaponId[lastIndex];
    offhandWeaponId[removeIndex] = offhandWeaponId[lastIndex];
    projectileItemId[removeIndex] = projectileItemId[lastIndex];
    spellBookId[removeIndex] = spellBookId[lastIndex];
    accessoryId[removeIndex] = accessoryId[lastIndex];
    stats[removeIndex] = stats[lastIndex];

    mask.removeLast();
    mainWeaponId.removeLast();
    offhandWeaponId.removeLast();
    projectileItemId.removeLast();
    spellBookId.removeLast();
    accessoryId.removeLast();
    stats.removeLast();
  }
}
