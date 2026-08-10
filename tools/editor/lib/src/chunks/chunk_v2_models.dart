import 'package:meta/meta.dart';

import '../domain/authoring_types.dart';
import '../levels/level_domain_models.dart';
import '../prefabs/domain/prefab_domain_models.dart';
import '../prefabs/models/models.dart';
import 'chunk_v2_collision_expansion.dart';
import 'chunk_v2_file_data.dart';
import 'chunk_v2_seam_analysis.dart';

/// Normal loading selects this only when every chunk is strict v2 and its
/// prefab dependencies are current. Export can update that current tree but
/// cannot migrate a legacy or mixed source generation.
@immutable
class ChunkV2Document extends AuthoringDocument {
  ChunkV2Document({
    required Iterable<ChunkV2FileData> chunks,
    required Map<String, String> sourcePathByChunkKey,
    required Map<String, String> baselineContentsByChunkKey,
    required this.prefabData,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    Map<String, double> groundTopYByLevelId = const <String, double>{},
    required Iterable<LevelDef> levels,
    required Iterable<String> availableLevelIds,
    required this.activeLevelId,
    Iterable<String> changedChunkKeys = const <String>[],
    Iterable<String> createdChunkKeys = const <String>[],
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
       groundTopYByLevelId = Map<String, double>.unmodifiable(
         groundTopYByLevelId,
       ),
       levels = List<LevelDef>.unmodifiable(levels),
       availableLevelIds = List<String>.unmodifiable(availableLevelIds),
       changedChunkKeys = List<String>.unmodifiable(
         changedChunkKeys.toSet().toList()..sort(),
       ),
       createdChunkKeys = List<String>.unmodifiable(
         createdChunkKeys.toSet().toList()..sort(),
       );

  final List<ChunkV2FileData> chunks;
  final Map<String, String> sourcePathByChunkKey;
  final Map<String, String> baselineContentsByChunkKey;
  final PrefabV3FileData prefabData;
  final PrefabTileFileData tileData;
  final Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey;
  final Map<String, double> groundTopYByLevelId;
  final List<LevelDef> levels;
  final List<String> availableLevelIds;
  final String? activeLevelId;
  final List<String> changedChunkKeys;

  /// Owners created in memory and therefore intentionally lacking baselines.
  final List<String> createdChunkKeys;

  ChunkV2Document copyWith({
    Iterable<ChunkV2FileData>? chunks,
    Map<String, String>? sourcePathByChunkKey,
    Map<String, String>? baselineContentsByChunkKey,
    PrefabV3FileData? prefabData,
    PrefabTileFileData? tileData,
    Map<String, PrefabV3VisualBounds>? visualBoundsByPrefabKey,
    Map<String, double>? groundTopYByLevelId,
    Iterable<LevelDef>? levels,
    Iterable<String>? availableLevelIds,
    String? activeLevelId,
    bool clearActiveLevelId = false,
    Iterable<String>? changedChunkKeys,
    Iterable<String>? createdChunkKeys,
  }) => ChunkV2Document(
    chunks: chunks ?? this.chunks,
    sourcePathByChunkKey: sourcePathByChunkKey ?? this.sourcePathByChunkKey,
    baselineContentsByChunkKey:
        baselineContentsByChunkKey ?? this.baselineContentsByChunkKey,
    prefabData: prefabData ?? this.prefabData,
    tileData: tileData ?? this.tileData,
    visualBoundsByPrefabKey:
        visualBoundsByPrefabKey ?? this.visualBoundsByPrefabKey,
    groundTopYByLevelId: groundTopYByLevelId ?? this.groundTopYByLevelId,
    levels: levels ?? this.levels,
    availableLevelIds: availableLevelIds ?? this.availableLevelIds,
    activeLevelId: clearActiveLevelId
        ? null
        : (activeLevelId ?? this.activeLevelId),
    changedChunkKeys: changedChunkKeys ?? this.changedChunkKeys,
    createdChunkKeys: createdChunkKeys ?? this.createdChunkKeys,
  );
}

/// Read-only scene projection for the current chunk-v2 plugin document.
@immutable
class ChunkV2Scene extends EditableScene {
  ChunkV2Scene({
    required Iterable<ChunkV2FileData> chunks,
    required Map<String, String> sourcePathByChunkKey,
    required this.prefabData,
    required this.tileData,
    required Map<String, PrefabV3VisualBounds> visualBoundsByPrefabKey,
    Map<String, double> groundTopYByLevelId = const <String, double>{},
    required Map<String, ChunkV2CollisionExpansionResult>
    collisionExpansionByChunkKey,
    required this.seamAnalysis,
    required Iterable<String> availableLevelIds,
    required this.activeLevelId,
  }) : chunks = List<ChunkV2FileData>.unmodifiable(chunks),
       sourcePathByChunkKey = Map<String, String>.unmodifiable(
         sourcePathByChunkKey,
       ),
       visualBoundsByPrefabKey = Map<String, PrefabV3VisualBounds>.unmodifiable(
         visualBoundsByPrefabKey,
       ),
       groundTopYByLevelId = Map<String, double>.unmodifiable(
         groundTopYByLevelId,
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
  final Map<String, double> groundTopYByLevelId;
  final Map<String, ChunkV2CollisionExpansionResult>
  collisionExpansionByChunkKey;
  final ChunkV2SeamAnalysis seamAnalysis;
  final List<String> availableLevelIds;
  final String? activeLevelId;
}
