import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_runner/core/accessories/accessory_id.dart';
import 'package:rpg_runner/core/ecs/world.dart';
import 'package:rpg_runner/core/projectiles/projectile_item_id.dart';
import 'package:rpg_runner/core/spells/spell_book_id.dart';
import 'package:rpg_runner/core/stats/character_stats_resolver.dart';
import 'package:rpg_runner/core/stats/gear_stat_bonuses.dart';
import 'package:rpg_runner/core/stats/resolved_stats_cache.dart';
import 'package:rpg_runner/core/weapons/weapon_id.dart';

void main() {
  test('resolved stats cache reuses value when loadout is unchanged', () {
    final world = EcsWorld();
    final resolver = _CountingResolver();
    final cache = ResolvedStatsCache(resolver: resolver);

    final entity = world.createEntity();
    world.equippedLoadout.add(entity);

    final first = cache.resolveForEntity(world, entity);
    final second = cache.resolveForEntity(world, entity);

    expect(resolver.calls, equals(1));
    expect(identical(first, second), isTrue);
    expect(world.resolvedStatsCache.has(entity), isTrue);
  });

  test('resolved stats cache recomputes when loadout changes', () {
    final world = EcsWorld();
    final resolver = _CountingResolver();
    final cache = ResolvedStatsCache(resolver: resolver);

    final entity = world.createEntity();
    world.equippedLoadout.add(entity);

    cache.resolveForEntity(world, entity);
    final li = world.equippedLoadout.indexOf(entity);
    world.equippedLoadout.mainWeaponId[li] = WeaponId.solidSword;
    cache.resolveForEntity(world, entity);

    expect(resolver.calls, equals(2));
  });

  test('resolved stats cache returns neutral when entity has no loadout', () {
    final world = EcsWorld();
    final resolver = _CountingResolver();
    final cache = ResolvedStatsCache(resolver: resolver);

    final entity = world.createEntity();
    final resolved = cache.resolveForEntity(world, entity);

    expect(resolver.calls, equals(0));
    expect(resolved, same(ResolvedStatsCache.neutral));
    expect(world.resolvedStatsCache.has(entity), isFalse);
  });
}

class _CountingResolver extends CharacterStatsResolver {
  _CountingResolver();

  int calls = 0;

  @override
  ResolvedCharacterStats resolveEquipped({
    required int mask,
    required WeaponId mainWeaponId,
    required WeaponId offhandWeaponId,
    required ProjectileItemId projectileItemId,
    required SpellBookId spellBookId,
    required AccessoryId accessoryId,
  }) {
    calls += 1;
    return const ResolvedCharacterStats(
      bonuses: GearStatBonuses(moveSpeedBonusBp: 123),
    );
  }
}
