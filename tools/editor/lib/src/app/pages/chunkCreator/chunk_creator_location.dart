import 'package:flutter/widgets.dart';
import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';

import '../../../chunks/chunk_v2_models.dart';
import '../../../domain/authoring_types.dart';
import '../../../terrain_authoring/terrain_polygon_interaction.dart';
import '../shared/editor_page_navigation_state.dart';
import 'v2/chunk_scene_coordinator.dart';

/// Stable Chunk owner and scene view; pending geometry and forms are excluded.
class ChunkCreatorLocation extends EditorPageLocation {
  const ChunkCreatorLocation({
    required this.levelId,
    required this.chunkKey,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.domain = ChunkSceneDomain.terrain,
    this.prefabSelectionKey,
    this.markerSelectionKey,
    this.waterId,
    this.showGrid = false,
    this.showShapeEdges = false,
    this.showElevationGuides = false,
    this.connectionsExpanded = false,
    this.connectionSide = TerrainBoundarySide.right,
    this.visualPreview = false,
    this.terrainSelection,
    this.terrainTool = TerrainPolygonTool.select,
  });

  final String? levelId;
  final String? chunkKey;
  final double zoom;
  final Offset pan;
  final ChunkSceneDomain domain;
  final String? prefabSelectionKey;
  final String? markerSelectionKey;
  final String? waterId;
  final bool showGrid;
  final bool showShapeEdges;
  final bool showElevationGuides;
  final bool connectionsExpanded;
  final TerrainBoundarySide connectionSide;
  final bool visualPreview;
  final TerrainPolygonSelection? terrainSelection;
  final TerrainPolygonTool terrainTool;

  @override
  AuthoringDocument restoreDocumentSelection(
    AuthoringDomainPlugin plugin,
    AuthoringDocument document,
  ) {
    if (document is! ChunkV2Document ||
        !document.availableLevelIds.contains(levelId)) {
      return document;
    }
    return plugin.applyEdit(
      document,
      AuthoringCommand(kind: 'set_active_level', payload: {'levelId': levelId}),
    );
  }
}
