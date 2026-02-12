import '../ecs/entity_id.dart';
import '../ecs/world.dart';
import 'character_stats_resolver.dart';
import 'gear_stat_bonuses.dart';

/// Resolves and caches loadout-derived stats per entity.
///
/// Cache entries are invalidated lazily by comparing current loadout fields
/// against the cached snapshot in [ResolvedStatsCacheStore].
class ResolvedStatsCache {
  const ResolvedStatsCache({
    CharacterStatsResolver resolver = const CharacterStatsResolver(),
  }) : _resolver = resolver;

  static const ResolvedCharacterStats neutral = ResolvedCharacterStats(
    bonuses: GearStatBonuses.zero,
  );

  final CharacterStatsResolver _resolver;

  /// Returns cached stats for [entity], recomputing only if loadout changed.
  ///
  /// Entities without `EquippedLoadoutStore` return neutral stats.
  ResolvedCharacterStats resolveForEntity(EcsWorld world, EntityId entity) {
    final loadout = world.equippedLoadout;
    final li = loadout.tryIndexOf(entity);
    if (li == null) return neutral;

    final currentMask = loadout.mask[li];
    final currentMainWeaponId = loadout.mainWeaponId[li];
    final currentOffhandWeaponId = loadout.offhandWeaponId[li];
    final currentProjectileItemId = loadout.projectileItemId[li];
    final currentSpellBookId = loadout.spellBookId[li];
    final currentAccessoryId = loadout.accessoryId[li];

    final cache = world.resolvedStatsCache;
    final ci = cache.tryIndexOf(entity);
    if (ci != null &&
        cache.matchesLoadout(
          cacheIndex: ci,
          mask: currentMask,
          mainWeaponId: currentMainWeaponId,
          offhandWeaponId: currentOffhandWeaponId,
          projectileItemId: currentProjectileItemId,
          spellBookId: currentSpellBookId,
          accessoryId: currentAccessoryId,
        )) {
      return cache.stats[ci];
    }

    final resolved = _resolver.resolveEquipped(
      mask: currentMask,
      mainWeaponId: currentMainWeaponId,
      offhandWeaponId: currentOffhandWeaponId,
      projectileItemId: currentProjectileItemId,
      spellBookId: currentSpellBookId,
      accessoryId: currentAccessoryId,
    );
    cache.setForEntity(
      entity,
      mask: currentMask,
      mainWeaponId: currentMainWeaponId,
      offhandWeaponId: currentOffhandWeaponId,
      projectileItemId: currentProjectileItemId,
      spellBookId: currentSpellBookId,
      accessoryId: currentAccessoryId,
      stats: resolved,
    );
    return resolved;
  }
}
