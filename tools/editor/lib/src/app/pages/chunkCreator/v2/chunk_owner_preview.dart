import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_polygon_level_visual_source.dart';
import 'chunk_scene_visual_source.dart';

/// Compact, read-only composition preview for one Chunk owner row.
class ChunkOwnerPreview extends StatelessWidget {
  const ChunkOwnerPreview({
    super.key,
    required this.workspaceRootPath,
    required this.chunk,
    required this.scene,
  });

  final String workspaceRootPath;
  final ChunkV2FileData chunk;
  final ChunkV2Scene scene;

  @override
  Widget build(BuildContext context) {
    final visualProjection = ChunkSceneVisualProjection.fromChunk(
      chunk: chunk,
      prefabData: scene.prefabData,
      tileData: scene.tileData,
      visualBoundsByPrefabKey: scene.visualBoundsByPrefabKey,
    );
    final belowTerrain = visualProjection
        .belowTerrain(chunk.groundBandZIndex)
        .toList(growable: false);
    final atOrAboveTerrain = visualProjection
        .atOrAboveTerrain(chunk.groundBandZIndex)
        .toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Preview of ${chunk.id}',
      child: RepaintBoundary(
        child: Container(
          width: 104,
          height: 68,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chunkWidth = math.max(1, chunk.width).toDouble();
                final chunkHeight = math.max(1, chunk.height).toDouble();
                final zoom = math.min(
                  constraints.maxWidth / chunkWidth,
                  constraints.maxHeight / chunkHeight,
                );
                final transform = TerrainPolygonViewportTransform(
                  origin: Offset(
                    (constraints.maxWidth - chunkWidth * zoom) * 0.5,
                    (constraints.maxHeight - chunkHeight * zoom) * 0.5,
                  ),
                  zoom: zoom,
                );
                return Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ChunkPolygonLevelVisualSource(
                      workspaceRootPath: workspaceRootPath,
                      chunk: chunk,
                      parallaxTheme: scene.activeParallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.background,
                    ),
                    if (belowTerrain.isNotEmpty)
                      ChunkSceneVisualSource(
                        workspaceRootPath: workspaceRootPath,
                        placements: belowTerrain,
                        transform: transform,
                      ),
                    ChunkPolygonLevelVisualSource(
                      workspaceRootPath: workspaceRootPath,
                      chunk: chunk,
                      parallaxTheme: scene.activeParallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.terrain,
                    ),
                    ChunkPolygonLevelVisualSource(
                      workspaceRootPath: workspaceRootPath,
                      chunk: chunk,
                      parallaxTheme: scene.activeParallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.foreground,
                    ),
                    if (atOrAboveTerrain.isNotEmpty)
                      ChunkSceneVisualSource(
                        workspaceRootPath: workspaceRootPath,
                        placements: atOrAboveTerrain,
                        transform: transform,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
