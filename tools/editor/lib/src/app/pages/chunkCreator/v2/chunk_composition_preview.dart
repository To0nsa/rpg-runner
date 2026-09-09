import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../parallax/parallax_domain_models.dart';
import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/terrain_polygon_scene_painter.dart';
import 'chunk_polygon_level_visual_source.dart';
import 'chunk_scene_visual_source.dart';

/// Fits an authored Chunk composition into its available space.
/// This read-only renderer is shared by Chunk thumbnails and the Level preview;
/// callers supply captured dependencies instead of constructing a write session.
class ChunkCompositionPreview extends StatelessWidget {
  const ChunkCompositionPreview({
    super.key,
    required this.workspaceRootPath,
    required this.chunk,
    required this.prefabData,
    required this.tileData,
    required this.visualBoundsByPrefabKey,
    required this.parallaxTheme,
    this.showForeground = false,
  });

  final String workspaceRootPath;
  final ChunkV2FileData chunk;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final ParallaxThemeDef? parallaxTheme;
  final bool showForeground;

  @override
  Widget build(BuildContext context) {
    final visualProjection = ChunkSceneVisualProjection.fromChunk(
      chunk: chunk,
      prefabData: prefabData,
      tileData: tileData,
      visualBoundsByPrefabKey: visualBoundsByPrefabKey,
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
      label: 'Preview of ${chunk.chunkKey}',
      child: RepaintBoundary(
        child: Container(
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
                if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                  return const SizedBox.shrink();
                }
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
                      parallaxTheme: parallaxTheme,
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
                      parallaxTheme: parallaxTheme,
                      transform: transform,
                      layer: ChunkPolygonLevelVisualLayer.terrain,
                    ),
                    if (showForeground)
                      ChunkPolygonLevelVisualSource(
                        workspaceRootPath: workspaceRootPath,
                        chunk: chunk,
                        parallaxTheme: parallaxTheme,
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
