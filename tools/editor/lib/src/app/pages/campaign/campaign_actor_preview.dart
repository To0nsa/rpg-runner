import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../campaign/campaign_marker_edit.dart';
import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_v2_actor_terrain_projection.dart';
import '../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../../../chunks/chunk_v2_marker_placement_projection.dart';
import '../../../prefabs/models/models.dart';
import '../chunkCreator/v2/chunk_encounter_projection.dart';
import '../chunkCreator/v2/chunk_actor_terrain_overlay_painter.dart';
import '../chunkCreator/v2/chunk_encounter_visual_source.dart';
import '../chunkCreator/v2/chunk_marker_placement_overlay_painter.dart';
import '../chunkCreator/v2/chunk_trap_visual_source.dart';
import '../shared/editor_scene_view_utils.dart';
import '../shared/terrain_polygon_scene_painter.dart';

/// Read-only composition of inherited and local actors using Chunk's existing
/// placement projections and visual layers. Geometry is cached independently
/// of pointer previews so dragging does not rebuild navigation graphs.
class CampaignActorPreview extends StatefulWidget {
  const CampaignActorPreview({
    super.key,
    required this.chunk,
    required this.prefabs,
    required this.entries,
    required this.root,
    required this.scale,
    required this.images,
    this.selectedKey,
    this.frame = 0,
    this.terrainActor,
  });
  final ChunkV2FileData chunk;
  final PrefabV3FileData prefabs;
  final List<CampaignMarkerEntry> entries;
  final String root;
  final double scale;
  final EditorUiImageCache images;
  final String? selectedKey;
  final int frame;
  final ChunkV2TerrainActor? terrainActor;
  @override
  State<CampaignActorPreview> createState() => _CampaignActorPreviewState();
}

class _CampaignActorPreviewState extends State<CampaignActorPreview> {
  ChunkV2CollisionExpansion? _expansion;
  ChunkV2ActorTerrainProjection? _terrain;
  @override
  void initState() {
    super.initState();
    _geometry();
  }

  @override
  void didUpdateWidget(covariant CampaignActorPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.chunk, widget.chunk) ||
        !identical(oldWidget.prefabs, widget.prefabs)) {
      _geometry();
    }
  }

  void _geometry() {
    _expansion = expandChunkV2Collision(
      chunk: widget.chunk,
      prefabs: widget.prefabs.prefabs,
      sourcePath: widget.chunk.chunkKey,
    ).expansion;
    _terrain = _expansion == null
        ? null
        : ChunkV2ActorTerrainProjection.build(_expansion!);
  }

  @override
  Widget build(BuildContext context) {
    final local = widget.entries.map((e) => e.placement).nonNulls;
    final chunk = widget.chunk.copyWith(
      markers: [
        ...widget.chunk.markers,
        for (final p in local.whereType<CampaignEnemySource>())
          PlacedMarkerDef(
            markerId: p.marker.enemyId.name,
            x: p.position.x.round(),
            y: p.position.y.round(),
            placement: p.marker.placement.name,
            chancePercent: p.marker.chancePercent,
            salt: p.marker.salt,
          ),
      ],
      traps: [
        ...widget.chunk.traps,
        ...local.whereType<CampaignTrapSource>().map((p) => p.trap),
      ],
      encounters: [
        ...widget.chunk.encounters,
        ...local.whereType<CampaignRescueSource>().map((p) => p.encounter),
      ],
    );
    final selected = widget.entries
        .where((e) => e.key == widget.selectedKey)
        .firstOrNull
        ?.placement;
    final transform = TerrainPolygonViewportTransform(
      origin: Offset.zero,
      zoom: widget.scale,
    );
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.terrainActor case final actor?)
            if (_terrain case final terrain?)
              CustomPaint(
                key: const ValueKey('campaign_actor_terrain_overlay'),
                painter: ChunkActorTerrainOverlayPainter(
                  projection: terrain,
                  actor: actor,
                  transform: transform,
                ),
              )
            else
              const Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Actor terrain unavailable: repair chunk geometry.',
                ),
              ),
          ChunkTrapVisualSource(
            workspaceRootPath: widget.root,
            images: widget.images,
            traps: chunk.traps,
            selected: selected is CampaignTrapSource ? selected.trap : null,
            previewFrame: widget.frame,
            transform: transform,
            pass: ChunkTrapVisualPass.sprites,
          ),
          if (_terrain != null && chunk.markers.isNotEmpty)
            ChunkMarkerPlacementOverlay(
              workspaceRootPath: widget.root,
              transform: transform,
              projection: ChunkV2MarkerPlacementProjection.build(
                chunk: chunk,
                actorTerrain: _terrain!,
                levelGroundTopY: 224,
              ),
            ),
          ChunkEncounterVisualSource(
            actors: projectChunkEncounterActors(
              chunk: chunk,
              expansion: _expansion,
              groundTopY: 224,
              workspaceRootPath: widget.root,
            ),
            groups: chunk.encounters,
            selected: null,
            transform: transform,
            chunkSize: const Size(600, 270),
            authoring: false,
            images: widget.images,
          ),
        ],
      ),
    );
  }
}
