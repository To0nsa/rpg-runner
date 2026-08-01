import 'package:meta/meta.dart';

import '../domain/authoring_types.dart';
import '../prefabs/domain/prefab_domain_models.dart';
import '../prefabs/models/models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';

/// Temporary read-only plugin document for an all-v2 chunk source tree.
///
/// Normal repository loading remains on the legacy chunk document until the
/// one Phase 4 schema cutover. Changed staging documents cannot be exported.
@immutable
class ChunkV2StagingDocument extends AuthoringDocument {
  ChunkV2StagingDocument({
    required Iterable<ChunkV2FileData> chunks,
    required Map<String, String> sourcePathByChunkKey,
    required Map<String, String> baselineContentsByChunkKey,
    required this.prefabData,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    required Iterable<String> availableLevelIds,
    required this.activeLevelId,
    Iterable<String> changedChunkKeys = const <String>[],
  }) : chunks = List<ChunkV2FileData>.unmodifiable(chunks),
       sourcePathByChunkKey = Map<String, String>.unmodifiable(
         sourcePathByChunkKey,
       ),
       baselineContentsByChunkKey = Map<String, String>.unmodifiable(
         baselineContentsByChunkKey,
       ),
       visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       availableLevelIds = List<String>.unmodifiable(availableLevelIds),
       changedChunkKeys = List<String>.unmodifiable(
         changedChunkKeys.toSet().toList()..sort(),
       );

  final List<ChunkV2FileData> chunks;
  final Map<String, String> sourcePathByChunkKey;
  final Map<String, String> baselineContentsByChunkKey;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final List<String> availableLevelIds;
  final String? activeLevelId;
  final List<String> changedChunkKeys;

  ChunkV2StagingDocument copyWith({
    Iterable<ChunkV2FileData>? chunks,
    Map<String, String>? sourcePathByChunkKey,
    Map<String, String>? baselineContentsByChunkKey,
    PrefabV3FileData? prefabData,
    PrefabTileFileData? tileData,
    Map<String, PrefabV3VisualBounds>? visualBoundsByPrefabKey,
    Iterable<String>? availableLevelIds,
    String? activeLevelId,
    bool clearActiveLevelId = false,
    Iterable<String>? changedChunkKeys,
  }) => ChunkV2StagingDocument(
    chunks: chunks ?? this.chunks,
    sourcePathByChunkKey: sourcePathByChunkKey ?? this.sourcePathByChunkKey,
    baselineContentsByChunkKey:
        baselineContentsByChunkKey ?? this.baselineContentsByChunkKey,
    prefabData: prefabData ?? this.prefabData,
    tileData: tileData ?? this.tileData,
    visualBoundsByPrefabKey:
        visualBoundsByPrefabKey ?? this.visualBoundsByPrefabKey,
    availableLevelIds: availableLevelIds ?? this.availableLevelIds,
    activeLevelId: clearActiveLevelId
        ? null
        : (activeLevelId ?? this.activeLevelId),
    changedChunkKeys: changedChunkKeys ?? this.changedChunkKeys,
  );
}

/// Read-only scene projection for the staged chunk-v2 plugin document.
@immutable
class ChunkV2StagingScene extends EditableScene {
  ChunkV2StagingScene({
    required Iterable<ChunkV2FileData> chunks,
    required Map<String, String> sourcePathByChunkKey,
    required this.prefabData,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    required Map<String, ChunkV2CollisionExpansionResult>
    collisionExpansionByChunkKey,
    required Iterable<String> availableLevelIds,
    required this.activeLevelId,
  }) : chunks = List<ChunkV2FileData>.unmodifiable(chunks),
       sourcePathByChunkKey = Map<String, String>.unmodifiable(
         sourcePathByChunkKey,
       ),
       visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       collisionExpansionByChunkKey =
           Map<String, ChunkV2CollisionExpansionResult>.unmodifiable(
             collisionExpansionByChunkKey,
           ),
       availableLevelIds = List<String>.unmodifiable(availableLevelIds);

  final List<ChunkV2FileData> chunks;
  final Map<String, String> sourcePathByChunkKey;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final Map<String, ChunkV2CollisionExpansionResult>
  collisionExpansionByChunkKey;
  final List<String> availableLevelIds;
  final String? activeLevelId;
}
