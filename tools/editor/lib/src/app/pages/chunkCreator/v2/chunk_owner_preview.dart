import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import 'chunk_composition_preview.dart';

/// Compact authored composition thumbnail for the Chunk owner catalog.
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
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    height: 68,
    child: ChunkCompositionPreview(
      workspaceRootPath: workspaceRootPath,
      chunk: chunk,
      prefabData: scene.prefabData,
      tileData: scene.tileData,
      visualBoundsByPrefabKey: scene.visualBoundsByPrefabKey,
      parallaxTheme: scene.activeParallaxTheme,
      showForeground: true,
    ),
  );
}
