import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_domain_plugin.dart';
import 'package:runner_editor/src/chunks/chunk_v2_authoring_polygon_signature.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/chunks/chunk_v2_seam_analysis.dart';
import 'package:runner_editor/src/chunks/chunk_v2_models.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

/// Stable profile fixture for the Phase 4 polygon-interaction budget.
///
/// The active 600 x 270 Chunk sits exactly at the representative 16 direct
/// shapes and 256 compiled edges. A second compatible Chunk makes the seam
/// overlay consume scheduler-reachable evidence without adding work to the
/// active owner-local drag reducer.
final class PolygonInteractionBenchmarkFixture {
  PolygonInteractionBenchmarkFixture._({
    required this.document,
    required this.mainChunk,
    required this.mainExpansion,
    required this.seamAnalysis,
    required this.authoringPolygonSignature,
  });

  static const String fixtureId = 'phase4-polygon-soft-budget-v1';
  static const String mainChunkKey = 'benchmark_main';
  static const String selectedShapeId = 'detail_001';
  static const int directShapeCount = 16;
  static const int selectedShapeVertexCount = 24;
  static const int placedPrefabCount = 43;
  static const int markerCount = 24;
  static const int compiledEdgeCount = 256;

  final ChunkV2Document document;
  final ChunkV2FileData mainChunk;
  final ChunkV2CollisionExpansion mainExpansion;
  final ChunkV2SeamAnalysis seamAnalysis;
  final String authoringPolygonSignature;

  String get sourceSignature => mainExpansion.geometry.sourceSignature();
  String get edgeSignature => mainExpansion.geometry.edgeSignature();
  String get seamSignature => seamAnalysis.reachableAdjacencyDigest;

  static PolygonInteractionBenchmarkFixture build() {
    final prefab = _benchmarkPrefab();
    final prefabData = PrefabV3FileData(
      slices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'benchmark_tile',
          sourceImagePath: 'assets/images/level/benchmark_fixture.png',
          x: 0,
          y: 0,
          width: 4,
          height: 4,
        ),
      ],
      prefabs: <PrefabV3Def>[prefab],
    );
    final tileData = PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    );
    final mainChunk = _benchmarkMainChunk();
    final neighborChunk = _benchmarkNeighborChunk();
    final chunks = <ChunkV2FileData>[mainChunk, neighborChunk];
    final sourcePaths = const <String, String>{
      mainChunkKey: 'benchmark/chunks/benchmark_main.json',
      'benchmark_neighbor': 'benchmark/chunks/benchmark_neighbor.json',
    };
    final expansions = <String, ChunkV2CollisionExpansionResult>{
      for (final chunk in chunks)
        chunk.chunkKey: expandChunkV2Collision(
          chunk: chunk,
          prefabs: prefabData.prefabs,
          sourcePath: sourcePaths[chunk.chunkKey]!,
        ),
    };
    final mainExpansion = expansions[mainChunkKey]!.expansion!;
    final levels = <LevelDef>[_benchmarkLevel()];
    final seamAnalysis = analyzeChunkV2Seams(
      chunks: chunks,
      levels: levels,
      collisionExpansionByChunkKey: expansions,
      sourcePathByChunkKey: sourcePaths,
    );
    final document = ChunkV2Document(
      chunks: chunks,
      sourcePathByChunkKey: sourcePaths,
      baselineContentsByChunkKey: <String, String>{
        for (final chunk in chunks)
          chunk.chunkKey: ChunkV2FileCodec.encode(chunk),
      },
      prefabData: prefabData,
      tileData: tileData,
      visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
        'benchmark_prefab': PrefabV3VisualBounds(widthPx: 4, heightPx: 4),
      },
      groundTopYByLevelId: const <String, double>{'benchmark': 220},
      levels: levels,
      availableLevelIds: const <String>['benchmark'],
      activeLevelId: 'benchmark',
    );
    return PolygonInteractionBenchmarkFixture._(
      document: document,
      mainChunk: mainChunk,
      mainExpansion: mainExpansion,
      seamAnalysis: seamAnalysis,
      authoringPolygonSignature: chunkV2AuthoringPolygonSignature(
        chunk: mainChunk,
        prefabs: prefabData.prefabs,
        expansion: mainExpansion,
      ),
    );
  }

  Future<PolygonInteractionBenchmarkSession> openSession({
    required String workspacePath,
  }) async {
    final plugin = PolygonInteractionBenchmarkPlugin(document);
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[plugin],
      ),
      initialPluginId: ChunkDomainPlugin.pluginId,
      initialWorkspacePath: workspacePath,
    );
    await controller.loadWorkspace();
    return PolygonInteractionBenchmarkSession(
      controller: controller,
      plugin: plugin,
    );
  }
}

final class PolygonInteractionBenchmarkSession {
  const PolygonInteractionBenchmarkSession({
    required this.controller,
    required this.plugin,
  });

  final EditorSessionController controller;
  final PolygonInteractionBenchmarkPlugin plugin;

  void dispose() => controller.dispose();
}

/// Fixture-only plugin that counts loads while delegating all domain behavior.
final class PolygonInteractionBenchmarkPlugin implements AuthoringDomainPlugin {
  PolygonInteractionBenchmarkPlugin(this.document);

  final ChunkV2Document document;
  final ChunkDomainPlugin _delegate = ChunkDomainPlugin();
  int loadCount = 0;

  @override
  String get id => ChunkDomainPlugin.pluginId;

  @override
  Future<AuthoringDocument> loadFromRepo(EditorWorkspace workspace) async {
    loadCount += 1;
    return document;
  }

  @override
  List<ValidationIssue> validate(AuthoringDocument document) =>
      _delegate.validate(document);

  @override
  EditableScene buildEditableScene(AuthoringDocument document) =>
      _delegate.buildEditableScene(document);

  @override
  AuthoringDocument applyEdit(
    AuthoringDocument document,
    AuthoringCommand command,
  ) => _delegate.applyEdit(document, command);

  @override
  PendingChanges describePendingChanges(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.describePendingChanges(workspace, document: document);

  @override
  Future<ExportResult> exportToRepo(
    EditorWorkspace workspace, {
    required AuthoringDocument document,
  }) => _delegate.exportToRepo(workspace, document: document);
}

PrefabV3Def _benchmarkPrefab() => PrefabV3Def(
  prefabKey: 'benchmark_prefab',
  id: 'benchmark_prefab',
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: const PrefabVisualSource.atlasSlice('benchmark_tile'),
  anchorXPx: 0,
  anchorYPx: 0,
  collisionShapes: <TerrainSourceShapeDef>[
    TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 0),
        TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 8),
      ],
    ),
  ],
  tags: const <String>['benchmark'],
);

ChunkV2FileData _benchmarkMainChunk() => ChunkV2FileData(
  chunkKey: PolygonInteractionBenchmarkFixture.mainChunkKey,
  id: PolygonInteractionBenchmarkFixture.mainChunkKey,
  revision: 1,
  status: chunkStatusActive,
  levelId: 'benchmark',
  tileSize: 16,
  width: 600,
  height: 270,
  difficulty: chunkDifficultyEarly,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>['benchmark'],
  tileLayers: const <TileLayerDef>[
    TileLayerDef(id: 'ground_preview', kind: 'ground'),
  ],
  prefabs: <PlacedPrefabDef>[
    for (
      var index = 0;
      index < PolygonInteractionBenchmarkFixture.placedPrefabCount;
      index += 1
    )
      PlacedPrefabDef(
        prefabId: 'benchmark_prefab',
        prefabKey: 'benchmark_prefab',
        x: 20 + (index % 15) * 36,
        y: 80 + (index ~/ 15) * 36,
      ),
  ],
  markers: <PlacedMarkerDef>[
    for (
      var index = 0;
      index < PolygonInteractionBenchmarkFixture.markerCount;
      index += 1
    )
      PlacedMarkerDef(
        markerId: index.isEven ? 'grojib' : 'hashash',
        x: 20 + index * 24,
        y: 200,
        salt: index,
      ),
  ],
  groundBandZIndex: 0,
  collisionShapes: <TerrainSourceShapeDef>[
    _selectedDetailShape(),
    for (var index = 2; index <= 15; index += 1) _detailRectangle(index),
    _groundShape(),
  ],
);

ChunkV2FileData _benchmarkNeighborChunk() => ChunkV2FileData(
  chunkKey: 'benchmark_neighbor',
  id: 'benchmark_neighbor',
  revision: 1,
  status: chunkStatusActive,
  levelId: 'benchmark',
  tileSize: 16,
  width: 600,
  height: 270,
  difficulty: chunkDifficultyEarly,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>['benchmark'],
  tileLayers: const <TileLayerDef>[],
  prefabs: const <PlacedPrefabDef>[],
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: <TerrainSourceShapeDef>[_groundShape()],
);

TerrainSourceShapeDef _selectedDetailShape() => TerrainSourceShapeDef(
  shapeId: PolygonInteractionBenchmarkFixture.selectedShapeId,
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: 60, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 72, yHalfPixels: 20),
    TerrainSourceVertexDef(xHalfPixels: 84, yHalfPixels: 24),
    TerrainSourceVertexDef(xHalfPixels: 94, yHalfPixels: 30),
    TerrainSourceVertexDef(xHalfPixels: 102, yHalfPixels: 38),
    TerrainSourceVertexDef(xHalfPixels: 108, yHalfPixels: 48),
    TerrainSourceVertexDef(xHalfPixels: 112, yHalfPixels: 60),
    TerrainSourceVertexDef(xHalfPixels: 112, yHalfPixels: 72),
    TerrainSourceVertexDef(xHalfPixels: 108, yHalfPixels: 84),
    TerrainSourceVertexDef(xHalfPixels: 102, yHalfPixels: 94),
    TerrainSourceVertexDef(xHalfPixels: 94, yHalfPixels: 102),
    TerrainSourceVertexDef(xHalfPixels: 84, yHalfPixels: 108),
    TerrainSourceVertexDef(xHalfPixels: 72, yHalfPixels: 112),
    TerrainSourceVertexDef(xHalfPixels: 60, yHalfPixels: 112),
    TerrainSourceVertexDef(xHalfPixels: 48, yHalfPixels: 108),
    TerrainSourceVertexDef(xHalfPixels: 38, yHalfPixels: 102),
    TerrainSourceVertexDef(xHalfPixels: 30, yHalfPixels: 94),
    TerrainSourceVertexDef(xHalfPixels: 24, yHalfPixels: 84),
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 72),
    TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 60),
    TerrainSourceVertexDef(xHalfPixels: 24, yHalfPixels: 48),
    TerrainSourceVertexDef(xHalfPixels: 30, yHalfPixels: 38),
    TerrainSourceVertexDef(xHalfPixels: 38, yHalfPixels: 30),
    TerrainSourceVertexDef(xHalfPixels: 48, yHalfPixels: 24),
  ],
);

TerrainSourceShapeDef _detailRectangle(int index) {
  final left = 160 + (index - 2) * 30;
  return TerrainSourceShapeDef(
    shapeId: 'detail_${index.toString().padLeft(3, '0')}',
    vertices: <TerrainSourceVertexDef>[
      TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: 20),
      TerrainSourceVertexDef(xHalfPixels: left + 20, yHalfPixels: 20),
      TerrainSourceVertexDef(xHalfPixels: left + 20, yHalfPixels: 40),
      TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: 40),
    ],
  );
}

TerrainSourceShapeDef _groundShape() => TerrainSourceShapeDef(
  shapeId: 'ground_001',
  surfaceKind: 'earth',
  materialKey: 'benchmark_ground',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 440),
    TerrainSourceVertexDef(xHalfPixels: 1200, yHalfPixels: 440),
    TerrainSourceVertexDef(xHalfPixels: 1200, yHalfPixels: 540),
    TerrainSourceVertexDef(xHalfPixels: 0, yHalfPixels: 540),
  ],
);

LevelDef _benchmarkLevel() => const LevelDef(
  levelId: 'benchmark',
  revision: 1,
  displayName: 'Polygon interaction benchmark',
  visualThemeId: 'benchmark',
  chunkThemeGroups: <String>[defaultChunkAssemblyGroupId],
  cameraCenterY: 135,
  groundTopY: 220,
  earlyPatternChunks: 2,
  easyPatternChunks: 0,
  normalPatternChunks: 0,
  noEnemyChunks: 0,
  enumOrdinal: 1,
  status: levelStatusActive,
);
