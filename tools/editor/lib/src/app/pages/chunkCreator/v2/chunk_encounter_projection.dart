import 'dart:ui';

import 'package:runner_core/encounters/encounter_definition.dart';
import 'package:runner_core/encounters/encounter_placement.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/navigation/terrain_spawn_placement.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:runner_core/tuning/flying_enemy_tuning.dart';

import '../../../../chunks/chunk_encounter_edit.dart';
import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import 'chunk_actor_idle_frame.dart';

Rect encounterTriggerBounds(EncounterDefinition group) => Rect.fromLTWH(
  group.trigger.x,
  group.trigger.y,
  group.trigger.width,
  group.trigger.height,
);

/// Read-only placement evidence for even an incomplete, saveable encounter draft.
/// Full-roster admission remains owned by the shared content pipeline.
final class ChunkEncounterActorProjection {
  const ChunkEncounterActorProjection({
    required this.selection,
    required this.member,
    required this.body,
    required this.bounds,
    required this.artFacing,
    required this.frame,
    required this.diagnostic,
  });
  final ChunkEncounterSelection selection;
  final EncounterParticipant member;
  final Offset body;
  final Rect bounds;
  final Facing artFacing;
  final ChunkActorIdleFrame? frame;
  final String? diagnostic;
}

List<ChunkEncounterActorProjection> projectChunkEncounterActors({
  required ChunkV2FileData chunk,
  required ChunkV2CollisionExpansion? expansion,
  required double? groundTopY,
  required String workspaceRootPath,
}) {
  if (chunk.encounters.isEmpty || expansion == null || groundTopY == null) {
    return const [];
  }
  final resolver = TerrainSpawnPlacementResolver.forGeometry(
    expansion.geometry,
  );
  return [
    for (final group in chunk.encounters)
      for (final member in [...group.npcs, ...group.enemies])
        _project(group, member, resolver, groundTopY, workspaceRootPath),
  ];
}

ChunkEncounterActorProjection _project(
  EncounterDefinition group,
  EncounterParticipant member,
  TerrainSpawnPlacementResolver resolver,
  double groundTopY,
  String root,
) {
  final request = createEncounterSpawnRequest(
    member: member,
    startX: 0,
    groundTopY: groundTopY,
    flyingHoverOffsetY: const UnocoDemonTuning().unocoDemonHoverOffsetY,
  );
  final result = resolver.resolve(request);
  final point = result.bodyCenter ?? request.desiredBodyCenter;
  final body = Offset(point.x, point.y);
  final (collider, anim, scale, facing) = switch (member) {
    EncounterNpcPlacement(:final npcId) => (
      const NpcCatalog().get(npcId).collider,
      const NpcCatalog().get(npcId).renderAnim,
      const NpcCatalog().get(npcId).renderScale,
      const NpcCatalog().get(npcId).artFacing,
    ),
    EncounterEnemyPlacement(:final enemyId) => (
      const EnemyCatalog().get(enemyId).collider,
      const EnemyCatalog().get(enemyId).renderAnim,
      const EnemyCatalog().get(enemyId).renderScale,
      const EnemyCatalog().get(enemyId).artFacingDir,
    ),
  };
  return ChunkEncounterActorProjection(
    selection: ChunkEncounterSelection(group.id, memberId: member.id),
    member: member,
    body: body,
    bounds: Rect.fromCenter(
      center:
          body +
          Offset(
            collider.offsetX * (member.facing == facing ? 1 : -1),
            collider.offsetY,
          ),
      width: collider.halfX * 2,
      height: collider.halfY * 2,
    ),
    artFacing: facing,
    frame: ChunkActorIdleFrame.fromDefinition(
      renderAnim: anim,
      renderScale: scale,
      workspaceRootPath: root,
    ),
    diagnostic: result.accepted ? null : result.diagnostic,
  );
}

ChunkEncounterSelection? hitTestChunkEncounter({
  required ChunkV2FileData chunk,
  required List<ChunkEncounterActorProjection> actors,
  required Offset point,
}) {
  for (final actor in actors.reversed) {
    if (actor.bounds.inflate(4).contains(point)) return actor.selection;
  }
  for (final group in chunk.encounters.reversed) {
    if (encounterTriggerBounds(group).contains(point)) {
      return ChunkEncounterSelection(group.id);
    }
  }
  return null;
}
