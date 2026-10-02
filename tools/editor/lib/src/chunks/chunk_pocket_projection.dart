import 'package:runner_core/collision/terrain/terrain_edge_id.dart';
import 'package:runner_core/collision/terrain/terrain_geometry.dart';
import 'package:runner_core/collision/terrain/terrain_pocket_query.dart';
import 'package:runner_core/collision/terrain/terrain_traversal_profile.dart';
import 'package:runner_core/ecs/stores/world_contact_capsule_store.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/players/player_catalog.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/players/player_tuning.dart';

/// One narrowing gap and all catalog actors for which Core confirms a wedge.
final class ChunkPocketWarning {
  ChunkPocketWarning({required this.pocket, required Iterable<String> actors})
    : actors = List.unmodifiable(actors);

  final TerrainPocket pocket;
  final List<String> actors;
}

/// Builds local fall-trap evidence for every gravity-driven movable actor.
///
/// Uses catalog capsules and traversal profiles, independent of placed spawns.
/// Flying Unoco and stationary Derf are excluded: a fall wedge does not prove
/// they are trapped. No graph or gameplay capability is invented for them.
/// Suitable for Flutter compute; neither files nor UI state enter the query.
List<ChunkPocketWarning> buildChunkPocketWarnings(TerrainGeometry geometry) {
  final query = TerrainPocketQuery(geometry);
  final warnings =
      <(TerrainEdgeId, TerrainEdgeId), (TerrainPocket, List<String>)>{};
  void add(
    String label,
    WorldContactCapsuleDef capsule,
    TerrainTraversalProfile profile,
  ) {
    for (final pocket in query.find(
      radiusTicks: capsule.radiusTicks,
      verticalHalfSegmentTicks: capsule.verticalHalfSegmentTicks,
      profile: profile,
    )) {
      final key = (pocket.leftEdgeId, pocket.rightEdgeId);
      final entry = warnings.putIfAbsent(key, () => (pocket, <String>[]));
      entry.$2.add(label);
    }
  }

  for (final character in PlayerCharacterRegistry.all) {
    final actor = PlayerCatalogDerived.from(
      character.catalog,
      movement: MovementTuningDerived.from(
        character.tuning.movement,
        tickHz: 60,
      ),
      resources: ResourceTuningDerived.from(character.tuning.resource),
    ).archetype;
    add(
      'Player: ${character.displayName}',
      actor.worldContactCapsule,
      actor.terrainTraversalProfile,
    );
  }
  const enemies = EnemyCatalog();
  for (final id in groundNavigatingEnemyIds) {
    final actor = enemies.terrainContactProfile(id);
    add('Enemy: ${id.name}', actor.capsule, actor.traversal);
  }
  const npcs = NpcCatalog();
  for (final id in NpcCatalog.supportedIds) {
    final actor = npcs.terrainContactProfile(id);
    add('NPC: ${id.name}', actor.capsule, actor.traversal);
  }
  return List.unmodifiable([
    for (final entry in warnings.values)
      ChunkPocketWarning(pocket: entry.$1, actors: entry.$2),
  ]);
}
