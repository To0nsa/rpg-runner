import '../domain/authoring_types.dart';
import '../terrain_authoring/terrain_source_models.dart';
import 'chunk_domain_models.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_models.dart';

/// Authored owner intent carried across a guarded Level-to-Chunk handoff.
final class ChunkLevelTarget {
  const ChunkLevelTarget(this.levelId, {this.chunkKey, this.groupId});

  final String levelId;
  final String? chunkKey;
  final String? groupId;
}

/// Reserved identity retained by the caller until creation succeeds or cancels.
/// Retrying this intent opens that owner without regenerating its content.
final class ChunkFlatStarterIntent {
  const ChunkFlatStarterIntent(
    this.levelId,
    this.chunkKey,
    this.id, {
    this.groupId = defaultChunkAssemblyGroupId,
    this.materialKey = 'grass_dirt',
  });

  final String levelId;
  final String chunkKey;
  final String id;
  final String groupId;
  final String materialKey;
}

/// Actionable target failure; navigation keeps the origin session intact.
final class ChunkTargetException implements Exception {
  const ChunkTargetException(
    this.code,
    this.message, {
    this.issues = const <ValidationIssue>[],
  });

  final String code;
  final String message;
  final List<ValidationIssue> issues;

  @override
  String toString() => '$code: $message';
}

/// Allocates a deterministic starter identity from current authored ownership.
/// Call once per handoff and retain the returned intent across retries.
ChunkFlatStarterIntent allocateFlatStarterIntent(
  ChunkV2Document document, {
  required String levelId,
  String? groupId,
}) {
  final level = document.levels
      .where((level) => level.levelId == levelId)
      .firstOrNull;
  if (level == null) {
    throw ChunkTargetException(
      'chunk_target_level_missing',
      'Level "$levelId" is no longer present. Refresh the Level library.',
    );
  }
  final group =
      groupId ??
      level.assembly?.segments.firstOrNull?.groupId ??
      defaultChunkAssemblyGroupId;
  if (!level.chunkThemeGroups.contains(group)) {
    throw ChunkTargetException(
      'chunk_target_group_missing',
      'Group "$group" is no longer present in $levelId. Choose a current group.',
    );
  }
  final base = '${levelId}_starter';
  final owned =
      document.chunks
          .where(
            (chunk) =>
                chunk.levelId == levelId &&
                (groupId == null || chunk.assemblyGroupId == group) &&
                (chunk.chunkKey == base ||
                    RegExp('^${RegExp.escape(base)}_[0-9]+\$')
                        .hasMatch(chunk.chunkKey)),
          )
          .toList()
        ..sort((a, b) => a.chunkKey.compareTo(b.chunkKey));
  if (owned.isNotEmpty) {
    final chunk = owned.first;
    return ChunkFlatStarterIntent(
      levelId,
      chunk.chunkKey,
      chunk.id,
      groupId: chunk.assemblyGroupId,
    );
  }
  final claimed = <String>{
    ...document.chunks.map((chunk) => chunk.id.toLowerCase()),
    ...document.sourcePathByChunkKey.keys.map((key) => key.toLowerCase()),
  };
  var id = base;
  var suffix = 2;
  while (claimed.contains(id)) {
    id = '${base}_${suffix++}';
  }
  return ChunkFlatStarterIntent(levelId, id, id, groupId: group);
}

/// Builds the standard authoring preset using the loaded Level ground and a
/// validated material key. Canonical ownership and geometry gates run in plugin.
ChunkV2FileData buildFlatStarter(
  ChunkV2Document document,
  ChunkFlatStarterIntent intent,
) {
  final level = document.levels
      .where((level) => level.levelId == intent.levelId)
      .firstOrNull;
  if (level == null || !level.chunkThemeGroups.contains(intent.groupId)) {
    throw const ChunkTargetException(
      'flat_starter_target_changed',
      'The target Level or group changed. Refresh and choose it again.',
    );
  }
  final materialIssues = document.starterMaterialIssues
      .where(
        (issue) =>
            issue.blocks(AuthoringOperation.save) &&
            (issue.ownerKey == null || issue.ownerKey == intent.materialKey),
      )
      .toList();
  if (!document.availableTerrainMaterialKeys.contains(intent.materialKey) ||
      materialIssues.isNotEmpty) {
    throw ChunkTargetException(
      'flat_starter_material_unavailable',
      'Repair terrain material "${intent.materialKey}" and its source images '
          'in Terrain Materials, then retry Add flat starter.',
      issues: materialIssues,
    );
  }
  final width = defaultChunkWidth;
  final height = defaultChunkHeight;
  final ground = level.groundTopY;
  if (!ground.isFinite ||
      ground < 0 ||
      ground >= height ||
      ground != ground.roundToDouble()) {
    throw ChunkTargetException(
      'flat_starter_ground_invalid',
      'The flat starter requires a whole-pixel ground height between 0 and '
          '${height - 1}. Open Chunk Creator to author custom geometry for '
          '${level.levelId}, or choose a Level using the standard ground preset.',
    );
  }
  final y = ground.toInt() * 2;
  return ChunkV2FileData(
    chunkKey: intent.chunkKey,
    id: intent.id,
    revision: 1,
    status: chunkStatusActive,
    levelId: intent.levelId,
    tileSize: defaultChunkTileSize,
    width: width,
    height: height,
    difficulty: chunkDifficultyEarly,
    assemblyGroupId: intent.groupId,
    tags: const <String>[],
    tileLayers: const <TileLayerDef>[],
    prefabs: const <PlacedPrefabDef>[],
    markers: const <PlacedMarkerDef>[],
    groundBandZIndex: 0,
    collisionShapes: <TerrainSourceShapeDef>[
      TerrainSourceShapeDef(
        shapeId: 'solid_001',
        surfaceKind: 'ground',
        materialKey: intent.materialKey,
        vertices: <TerrainSourceVertexDef>[
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: y),
          TerrainSourceVertexDef(xHalfPixels: width * 2, yHalfPixels: y),
          TerrainSourceVertexDef(
            xHalfPixels: width * 2,
            yHalfPixels: height * 2,
          ),
          TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: height * 2),
        ],
      ),
    ],
  );
}
