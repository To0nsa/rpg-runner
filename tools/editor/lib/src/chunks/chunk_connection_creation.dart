import 'package:runner_core/collision/terrain/terrain_boundary_signature.dart';
import 'package:runner_core/collision/terrain/terrain_polygon.dart';
import 'package:runner_core/levels/terrain_elevation.dart';

import '../domain/authoring_types.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';
import 'chunk_level_target.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_models.dart';

/// Frozen creation intent for a flat successor at the predecessor's exact exit
/// height. The predecessor and Level guides are checked again before the new
/// independently editable Chunk is added to history.
final class ChunkConnectionCreation {
  const ChunkConnectionCreation({
    required this.predecessorKey,
    required this.predecessorSignature,
    required this.heightStepPx,
    required this.groundTopY,
    required this.chunkKey,
    required this.groupId,
    required this.difficulty,
  });
  final String predecessorKey;
  final String predecessorSignature;
  final int heightStepPx;
  final double groundTopY;
  final String chunkKey;
  final String groupId;
  final String difficulty;
}

/// Read-only facts used by the creation form, from current compiled geometry.
final class ChunkConnectionTemplate {
  const ChunkConnectionTemplate({
    required this.predecessor,
    required this.signature,
    required this.boundary,
    required this.presets,
    required this.materialKey,
    required this.surfaceKind,
  });
  final ChunkV2FileData predecessor;
  final String signature;
  final TerrainBoundarySignature boundary;
  final TerrainElevationPresets presets;
  final String materialKey;
  final String? surfaceKind;
}

ChunkConnectionTemplate inspectChunkConnectionTemplate(
  ChunkV2Document document,
  String predecessorKey,
) {
  final predecessor = document.chunks
      .where((chunk) => chunk.chunkKey == predecessorKey)
      .firstOrNull;
  if (predecessor == null || predecessor.levelId != document.activeLevelId) {
    throw const ChunkTargetException(
      'connecting_chunk_predecessor_missing',
      'Select a current chunk in this Level.',
    );
  }
  final level = document.levels.firstWhere(
    (level) => level.levelId == predecessor.levelId,
  );
  if (predecessor.width != defaultChunkWidth) {
    throw const ChunkTargetException(
      'connecting_chunk_dimensions',
      'Use the Level runtime chunk width before creating a connecting starter.',
    );
  }
  final result = expandChunkV2Collision(
    chunk: predecessor,
    prefabs: document.prefabData.prefabs,
    sourcePath: document.sourcePathByChunkKey[predecessorKey] ?? predecessorKey,
  );
  final expansion = result.expansion;
  if (expansion == null) {
    throw ChunkTargetException(
      'connecting_chunk_source_invalid',
      'Repair the current terrain before creating a connection.',
      issues: result.issues,
    );
  }
  final boundary = buildTerrainBoundarySignature(
    chunkKey: predecessorKey,
    chunkWidth: predecessor.width,
    geometry: expansion.geometry,
    side: TerrainBoundarySide.right,
  );
  const unsupported = ChunkTargetException(
    'connecting_chunk_manual_profile',
    'This edge needs manual terrain authoring. The starter supports one solid ground interval on the half-pixel grid. Use the connection profile as a drawing guide.',
  );
  if (boundary.coverageIntervals.length != 1) throw unsupported;
  final interval = boundary.coverageIntervals.single;
  if (interval.collisionMode != TerrainCollisionMode.solid ||
      interval.minYTicks % 512 != 0 ||
      interval.maxYTicks % 512 != 0) {
    throw unsupported;
  }
  final topEdges = expansion.geometry.edges
      .where(
        (edge) =>
            edge.start.xTicks == predecessor.width * 1024 &&
                edge.start.yTicks == interval.minYTicks ||
            edge.end.xTicks == predecessor.width * 1024 &&
                edge.end.yTicks == interval.minYTicks,
      )
      .toList();
  final material = topEdges
      .map((edge) => edge.materialKey)
      .whereType<String>()
      .firstOrNull;
  if (material == null ||
      !document.availableTerrainMaterialKeys.contains(material) ||
      document.starterMaterialIssues.any(
        (issue) =>
            issue.blocks(AuthoringOperation.save) &&
            (issue.ownerKey == null || issue.ownerKey == material),
      )) {
    throw const ChunkTargetException(
      'connecting_chunk_material_unavailable',
      'Repair the entrance terrain material before creating this chunk.',
    );
  }
  return ChunkConnectionTemplate(
    predecessor: predecessor,
    signature: expansion.geometry.sourceSignature(),
    boundary: boundary,
    presets: level.elevationPresets,
    materialKey: material,
    surfaceKind: topEdges.firstOrNull?.surfaceKind,
  );
}

/// Compiles the proposed starter and proves its entrance; never approximates a
/// compound boundary by its top height. This function performs no writes.
ChunkV2FileData buildConnectingChunk(
  ChunkV2Document document,
  ChunkConnectionCreation intent,
) {
  final template = inspectChunkConnectionTemplate(
    document,
    intent.predecessorKey,
  );
  final predecessor = template.predecessor;
  if (template.signature != intent.predecessorSignature ||
      template.presets.stepPx != intent.heightStepPx ||
      template.presets.groundTopY != intent.groundTopY) {
    throw const ChunkTargetException(
      'connecting_chunk_source_changed',
      'The predecessor or elevation settings changed. Open a fresh preview.',
    );
  }
  final level = document.levels.firstWhere(
    (level) => level.levelId == predecessor.levelId,
  );
  if (!level.chunkThemeGroups.contains(intent.groupId) ||
      !const ['early', 'easy', 'normal', 'hard'].contains(intent.difficulty)) {
    throw const ChunkTargetException(
      'connecting_chunk_pool_changed',
      'Choose a current group and difficulty.',
    );
  }
  final bottom = template.boundary.coverageIntervals.single.maxYTicks ~/ 512;
  final entranceY = template.boundary.coverageIntervals.single.minYTicks ~/ 512;
  final width = predecessor.width * 2;
  if (entranceY < 0 || entranceY >= bottom || bottom > predecessor.height * 2) {
    throw const ChunkTargetException(
      'connecting_chunk_dimensions',
      'This edge needs a valid solid depth. Author it with the boundary guide.',
    );
  }
  TerrainSourceVertexDef vertex(int x, int y) =>
      TerrainSourceVertexDef(xHalfPixels: x, yHalfPixels: y);
  final chunk = ChunkV2FileData(
    chunkKey: intent.chunkKey,
    id: intent.chunkKey,
    revision: 1,
    status: chunkStatusActive,
    levelId: predecessor.levelId,
    tileSize: predecessor.tileSize,
    width: predecessor.width,
    height: predecessor.height,
    difficulty: intent.difficulty,
    assemblyGroupId: intent.groupId,
    tags: [],
    tileLayers: [],
    prefabs: [],
    markers: [],
    groundBandZIndex: predecessor.groundBandZIndex,
    collisionShapes: [
      TerrainSourceShapeDef(
        shapeId: 'solid_001',
        surfaceKind: template.surfaceKind,
        materialKey: template.materialKey,
        vertices: [
          vertex(0, entranceY),
          vertex(width, entranceY),
          vertex(width, bottom),
          vertex(0, bottom),
        ],
      ),
    ],
  );
  final result = expandChunkV2Collision(
    chunk: chunk,
    prefabs: document.prefabData.prefabs,
    sourcePath: chunk.chunkKey,
  );
  final expansion = result.expansion;
  if (expansion == null ||
      !compareTerrainBoundaries(
        left: template.boundary,
        right: buildTerrainBoundarySignature(
          chunkKey: chunk.chunkKey,
          chunkWidth: chunk.width,
          geometry: expansion.geometry,
          side: TerrainBoundarySide.left,
        ),
      ).isCompatible) {
    throw ChunkTargetException(
      'connecting_chunk_manual_profile',
      'The starter cannot reproduce this complete boundary. Use manual authoring with the connection guide.',
      issues: result.issues,
    );
  }
  return chunk;
}
