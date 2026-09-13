import 'package:runner_core/collision/terrain/terrain_numeric.dart';

import '../../../../chunks/chunk_v2_collision_expansion.dart';
import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../terrain_authoring/terrain_source_models.dart';

/// Exact whole-pixel targets for Chunk rectangle gestures, in stable source
/// order. Fractional prefab/terrain vertices cannot move to become snap targets.
List<TerrainSourceVertexDef> chunkWholePixelSnapVertices({
  required ChunkV2FileData chunk,
  ChunkV2CollisionExpansion? expansion,
  String? excludingTerrainId,
  String? excludingWaterId,
}) =>
    [
          for (final shape in chunk.collisionShapes)
            if (shape.shapeId != excludingTerrainId) ...shape.vertices,
          for (final shape in expansion?.expandedPrefabShapes ?? [])
            for (final vertex in shape.vertices)
              if (vertex.xTicks % terrainPhysicsTicksPerWorldUnit == 0 &&
                  vertex.yTicks % terrainPhysicsTicksPerWorldUnit == 0)
                TerrainSourceVertexDef(
                  xHalfPixels:
                      vertex.xTicks ~/ terrainPhysicsTicksPerWorldUnit * 2,
                  yHalfPixels:
                      vertex.yTicks ~/ terrainPhysicsTicksPerWorldUnit * 2,
                ),
          for (final region in chunk.waterRegions)
            if (region.id != excludingWaterId)
              for (final x in [region.x, region.x + region.width])
                for (final y in [region.y, region.y + region.height])
                  TerrainSourceVertexDef(
                    xHalfPixels: x * 2,
                    yHalfPixels: y * 2,
                  ),
        ]
        .where(
          (vertex) =>
              vertex.xHalfPixels.isEven &&
              vertex.yHalfPixels.isEven &&
              vertex.xHalfPixels >= 0 &&
              vertex.xHalfPixels <= chunk.width * 2 &&
              vertex.yHalfPixels >= 0 &&
              vertex.yHalfPixels <= chunk.height * 2,
        )
        .toList(growable: false);
