import 'package:runner_core/collision/terrain/terrain_authoring_issue.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/track/staged_terrain_data.dart';

import 'polygon_terrain_compilation.dart';
import 'polygon_terrain_render.dart';
import 'polygon_terrain_source.dart';
import 'polygon_tile_source.dart';

const int _gridSnap = 16;

/// Complete typed runtime products for one accepted current-schema chunk.
final class PolygonTerrainRuntimeChunk {
  const PolygonTerrainRuntimeChunk({
    required this.sourcePath,
    required this.compiled,
    required this.stagedTerrain,
    required this.pattern,
  });

  final String sourcePath;
  final PolygonTerrainCompiledChunk compiled;
  final StagedTerrainChunkData stagedTerrain;
  final ChunkPattern pattern;
}

/// Fail-closed result for one chunk's runtime materialization.
final class PolygonTerrainRuntimeChunkResult {
  PolygonTerrainRuntimeChunkResult({
    required this.chunk,
    required Iterable<PolygonTerrainGenerationIssue> issues,
  }) : issues = canonicalTerrainAuthoringIssues(issues);

  final PolygonTerrainRuntimeChunk? chunk;
  final List<PolygonTerrainGenerationIssue> issues;
}

/// Compiles and materializes one chunk entirely from explicit source strings.
///
/// The operation performs no filesystem access and returns no partial typed
/// product when parsing, Core compilation, or runtime visual materialization
/// reports a blocker.
PolygonTerrainRuntimeChunkResult compilePolygonTerrainRuntimeChunkSource({
  required String prefabSourcePath,
  required String prefabContents,
  required String tileSourcePath,
  required String tileContents,
  required String chunkSourcePath,
  required String chunkContents,
}) {
  prefabSourcePath = canonicalPolygonTerrainSourcePath(prefabSourcePath);
  tileSourcePath = canonicalPolygonTerrainSourcePath(tileSourcePath);
  chunkSourcePath = canonicalPolygonTerrainSourcePath(chunkSourcePath);
  final compilation = compilePolygonTerrainSourceText(
    prefabSourcePath: prefabSourcePath,
    prefabSource: prefabContents,
    chunkSourcePath: chunkSourcePath,
    chunkSource: chunkContents,
  );
  final compiled = compilation.compiled;
  if (compiled == null) {
    return PolygonTerrainRuntimeChunkResult(
      chunk: null,
      issues: compilation.issues,
    );
  }

  final PolygonTileSourceSet tileSources;
  try {
    tileSources = decodePolygonTileSources(
      tileContents,
      sourcePath: tileSourcePath,
    );
  } on FormatException catch (error) {
    return PolygonTerrainRuntimeChunkResult(
      chunk: null,
      issues: <PolygonTerrainGenerationIssue>[
        _issue(
          code: 'tile_source_invalid',
          message: error.message.toString(),
          sourcePath: tileSourcePath,
          ownerKey: tileSourcePath,
        ),
      ],
    );
  }

  final prefabSources = decodePolygonTerrainPrefabs(
    prefabContents,
    sourcePath: prefabSourcePath,
  );
  return materializePolygonTerrainRuntimeChunk(
    sourcePath: chunkSourcePath,
    compiled: compiled,
    prefabSources: prefabSources,
    tileSources: tileSources,
  );
}

/// Materializes Core staged terrain and `ChunkPattern` data from one accepted
/// compile and already decoded visual catalogs.
PolygonTerrainRuntimeChunkResult materializePolygonTerrainRuntimeChunk({
  required String sourcePath,
  required PolygonTerrainCompiledChunk compiled,
  required PolygonTerrainPrefabSourceSet prefabSources,
  required PolygonTileSourceSet tileSources,
}) {
  sourcePath = canonicalPolygonTerrainSourcePath(sourcePath);
  final issues = <PolygonTerrainGenerationIssue>[];
  final slicesById = <String, PolygonTerrainSliceSource>{
    for (final slice in prefabSources.slices) slice.id: slice,
    for (final slice in tileSources.slices) slice.id: slice,
  };
  final modulesById = <String, PolygonTileModuleSource>{
    for (final module in tileSources.modules) module.id: module,
  };
  final prefabsByKey = <String, PolygonTerrainPrefabSource>{
    for (final prefab in prefabSources.prefabs) prefab.prefabKey: prefab,
  };
  final sprites = <ChunkVisualSpriteRel>[];
  for (final placement in compiled.chunk.placements) {
    final prefabRef = placement.resolvedPrefabRef;
    final prefab = prefabsByKey[prefabRef];
    if (prefab == null) {
      issues.add(
        _issue(
          code: 'missing_prefab_key',
          message: 'Placed prefab references unknown prefabKey "$prefabRef".',
          sourcePath: sourcePath,
          ownerKey: compiled.chunk.chunkKey,
        ),
      );
      continue;
    }
    final visual = prefab.visualSource;
    if (visual == null) continue;
    sprites.addAll(
      _materializeVisualSprites(
        prefab: prefab,
        visual: visual,
        placement: placement,
        slicesById: slicesById,
        modulesById: modulesById,
        sourcePath: sourcePath,
        chunkKey: compiled.chunk.chunkKey,
        issues: issues,
      ),
    );
  }

  final markers = <SpawnMarker>[];
  for (final marker in compiled.chunk.markers) {
    final enemyId = _enemyId(marker.markerId);
    if (enemyId == null) {
      issues.add(
        _issue(
          code: 'unknown_enemy_marker_id',
          message: 'Unknown markerId "${marker.markerId}".',
          sourcePath: sourcePath,
          ownerKey: compiled.chunk.chunkKey,
        ),
      );
      continue;
    }
    markers.add(
      SpawnMarker(
        enemyId: enemyId,
        x: marker.x.toDouble(),
        chancePercent: marker.chancePercent,
        salt: marker.salt,
        placement: _placementMode(marker.placement),
      ),
    );
  }

  if (issues.isNotEmpty) {
    return PolygonTerrainRuntimeChunkResult(chunk: null, issues: issues);
  }
  return PolygonTerrainRuntimeChunkResult(
    chunk: PolygonTerrainRuntimeChunk(
      sourcePath: sourcePath,
      compiled: compiled,
      stagedTerrain: materializeStagedTerrainChunk(compiled),
      pattern: ChunkPattern(
        name: compiled.chunk.id,
        chunkKey: compiled.chunk.chunkKey,
        assemblyGroupId: compiled.chunk.assemblyGroupId,
        visualSprites: List<ChunkVisualSpriteRel>.unmodifiable(sprites),
        spawnMarkers: List<SpawnMarker>.unmodifiable(markers),
      ),
    ),
    issues: const <PolygonTerrainGenerationIssue>[],
  );
}

List<ChunkVisualSpriteRel> _materializeVisualSprites({
  required PolygonTerrainPrefabSource prefab,
  required PolygonTerrainPrefabVisualSource visual,
  required PolygonTerrainPlacementSource placement,
  required Map<String, PolygonTerrainSliceSource> slicesById,
  required Map<String, PolygonTileModuleSource> modulesById,
  required String sourcePath,
  required String chunkKey,
  required List<PolygonTerrainGenerationIssue> issues,
}) {
  final scale = placement.scaleTenths / 10;
  if (visual.type == 'atlas_slice') {
    final slice = slicesById[visual.referenceId];
    if (slice == null) {
      issues.add(
        _issue(
          code: 'missing_slice',
          message: 'Missing atlas slice "${visual.referenceId}".',
          sourcePath: sourcePath,
          ownerKey: chunkKey,
        ),
      );
      return const <ChunkVisualSpriteRel>[];
    }
    return <ChunkVisualSpriteRel>[
      _sprite(
        slice: slice,
        prefab: prefab,
        placement: placement,
        scale: scale,
        localX: 0,
        localY: 0,
      ),
    ];
  }

  final module = modulesById[visual.referenceId];
  if (module == null) {
    issues.add(
      _issue(
        code: 'missing_module',
        message: 'Missing platform module "${visual.referenceId}".',
        sourcePath: sourcePath,
        ownerKey: chunkKey,
      ),
    );
    return const <ChunkVisualSpriteRel>[];
  }
  final sprites = <ChunkVisualSpriteRel>[];
  for (final cell in module.cells) {
    final slice = slicesById[cell.sliceId];
    if (slice == null) {
      issues.add(
        _issue(
          code: 'missing_tile_slice',
          message:
              'Missing tile slice "${cell.sliceId}" for module "${module.id}".',
          sourcePath: sourcePath,
          ownerKey: chunkKey,
        ),
      );
      continue;
    }
    sprites.add(
      _sprite(
        slice: slice,
        prefab: prefab,
        placement: placement,
        scale: scale,
        localX: cell.gridX * _gridSnap,
        localY: cell.gridY * _gridSnap,
      ),
    );
  }
  return sprites;
}

ChunkVisualSpriteRel _sprite({
  required PolygonTerrainSliceSource slice,
  required PolygonTerrainPrefabSource prefab,
  required PolygonTerrainPlacementSource placement,
  required double scale,
  required int localX,
  required int localY,
}) {
  final width = slice.width * scale;
  final height = slice.height * scale;
  return ChunkVisualSpriteRel(
    assetPath: _runtimeAssetPath(slice.sourceImagePath),
    srcX: slice.x,
    srcY: slice.y,
    srcWidth: slice.width,
    srcHeight: slice.height,
    x:
        placement.x +
        _transformLocalAxisStart(
          start: (-prefab.anchorXPx + localX) * scale,
          extent: width,
          flip: placement.flipX,
        ),
    y:
        placement.y +
        _transformLocalAxisStart(
          start: (-prefab.anchorYPx + localY) * scale,
          extent: height,
          flip: placement.flipY,
        ),
    width: width,
    height: height,
    zIndex: placement.zIndex,
    flipX: placement.flipX,
    flipY: placement.flipY,
  );
}

String _runtimeAssetPath(String authoredPath) {
  const prefix = 'assets/images/';
  return authoredPath.startsWith(prefix)
      ? authoredPath.substring(prefix.length)
      : authoredPath;
}

double _transformLocalAxisStart({
  required double start,
  required double extent,
  required bool flip,
}) => flip ? -(start + extent) : start;

EnemyId? _enemyId(String markerId) => switch (markerId) {
  'derf' => EnemyId.derf,
  'grojib' => EnemyId.grojib,
  'hashash' => EnemyId.hashash,
  'unocoDemon' => EnemyId.unocoDemon,
  _ => null,
};

SpawnPlacementMode _placementMode(String placement) => switch (placement) {
  'highestSurfaceAtX' => SpawnPlacementMode.highestSurfaceAtX,
  'obstacleTop' => SpawnPlacementMode.obstacleTop,
  _ => SpawnPlacementMode.ground,
};

PolygonTerrainGenerationIssue _issue({
  required String code,
  required String message,
  required String sourcePath,
  required String ownerKey,
}) => TerrainAuthoringIssue(
  severity: TerrainAuthoringIssueSeverity.error,
  code: code,
  message: message,
  sourcePath: sourcePath,
  ownerKey: ownerKey,
  placementKey: null,
  shapeId: null,
  elementIndex: null,
);
