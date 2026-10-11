import '../ecs/entity_id.dart';
import '../ecs/resource_restoration.dart';
import '../ecs/stores/restoration_item_store.dart';
import '../ecs/world.dart';
import 'boss_resource_supply_definition.dart';

/// Active combat context from the arena, never a render snapshot or boss AI.
/// [occurrence] is the streamed chunk index, not the reusable authored arena ID.
/// Horizontal bounds use world units and confine the entire pickup footprint.
final class BossResourceSupplyEncounter {
  const BossResourceSupplyEncounter({
    required this.occurrence,
    required this.boss,
    required this.minX,
    required this.maxX,
    required this.definition,
  });

  final int occurrence;
  final EntityId boss;
  final double minX;
  final double maxX;
  final BossResourceSupplyDefinition definition;
}

/// Earns one pickup per combat occurrence after damage and arena resolution.
/// Failed placement stays pending through healing, but never beyond combat.
final class BossResourceSupplySystem {
  int? _occurrence;
  bool _reached = false;
  bool _spawned = false;

  /// [spawn] returns a terrain-checked restoration entity or null to retry.
  /// A null encounter ends combat and removes only this system's owned pickups.
  /// Equal mana/stamina fractions choose mana, including when both are full.
  void step(
    EcsWorld world, {
    required EntityId player,
    required BossResourceSupplyEncounter? encounter,
    required EntityId? Function(
      BossResourceSupplyEncounter encounter,
      RestorationStat stat,
    )
    spawn,
  }) {
    final pi = world.health.tryIndexOf(player);
    final bi = encounter == null
        ? null
        : world.health.tryIndexOf(encounter.boss);
    if (encounter == null ||
        pi == null ||
        bi == null ||
        world.health.hp[pi] <= 0 ||
        world.health.hp[bi] <= 0 ||
        world.deathState.has(player) ||
        world.deathState.has(encounter.boss)) {
      endCombat(world);
      return;
    }
    if (_occurrence != encounter.occurrence) {
      endCombat(world);
      _occurrence = encounter.occurrence;
      _reached = false;
      _spawned = false;
    }
    if (_spawned) return;
    final maximum = world.health.hpMax[bi];
    if (maximum <= 0) return;
    _reached |=
        world.health.hp[bi] * 10000 <=
        maximum * encounter.definition.healthThresholdBp;
    if (!_reached) return;

    final stat = ResourceRestoration.lowestStat(
      world,
      entity: player,
      candidates: const [RestorationStat.mana, RestorationStat.stamina],
    );
    if (stat == null) return;
    final pickup = spawn(encounter, stat);
    if (pickup == null) return;
    world.bossResourcePickup.addEntity(pickup);
    _spawned = true;
  }

  /// Cancels pending supply and clears lifecycle-registered pickup ownership.
  /// Retaining consumption prevents a completed occurrence from being rearmed.
  void endCombat(EcsWorld world) {
    final owned = world.bossResourcePickup.denseEntities;
    while (owned.isNotEmpty) {
      world.destroyEntity(owned.last);
    }
    _reached = false;
    _spawned = true;
  }
}
