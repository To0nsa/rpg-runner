import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_prefab_scene_gesture.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_prefab_surface_snap.dart';
import 'package:runner_editor/src/chunks/chunk_v2_collision_expansion.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('place preview stays local and finish builds one snapped add', () {
    final gesture = ChunkPrefabSceneGesture();
    final chunk = _chunk();

    expect(
      gesture.beginPlace(
        pointer: 1,
        worldPoint: const Offset(23, 39),
        chunk: chunk,
        prefab: _prefab(),
      ),
      isTrue,
    );
    expect(gesture.candidate?.x, 16);
    expect(gesture.candidate?.y, 32);
    expect(chunk.prefabs, isEmpty);

    gesture.update(pointer: 1, worldPoint: const Offset(42, 58));
    expect(gesture.candidate?.x, 48);
    expect(gesture.candidate?.y, 64);
    expect(chunk.prefabs, isEmpty);

    final result = gesture.finish(pointer: 1, worldPoint: const Offset(42, 58));
    expect(result?.commit?.after.prefabs.single, result?.candidate);
    expect(result?.commit?.after.prefabs.single.x, 48);
    expect(gesture.hasActiveOperation, isFalse);
  });

  test('move preserves grab offset and zero-distance finish is a no-op', () {
    final gesture = ChunkPrefabSceneGesture();
    final chunk = _chunk(
      prefabs: const <PlacedPrefabDef>[
        PlacedPrefabDef(prefabId: 'rock', prefabKey: 'rock', x: 32, y: 48),
      ],
    );
    final selection = buildChunkPlacedPrefabSelections(chunk.prefabs).single;

    gesture.beginMove(
      pointer: 7,
      worldPoint: const Offset(35, 50),
      chunk: chunk,
      selection: selection,
    );
    expect(gesture.hiddenSourceIndex, selection.sourceIndex);
    final noOp = gesture.finish(pointer: 7, worldPoint: const Offset(35, 50));
    expect(noOp?.commit, isNull);

    gesture.beginMove(
      pointer: 8,
      worldPoint: const Offset(35, 50),
      chunk: chunk,
      selection: selection,
    );
    final moved = gesture.finish(pointer: 8, worldPoint: const Offset(51, 66));
    expect(moved?.candidate.x, 48);
    expect(moved?.candidate.y, 64);
    expect(moved?.commit?.before.prefabs.single.x, 32);
  });

  test('cancel drops the preview without constructing a command', () {
    final gesture = ChunkPrefabSceneGesture();
    gesture.beginPlace(
      pointer: 1,
      worldPoint: Offset.zero,
      chunk: _chunk(),
      prefab: _prefab(),
    );

    expect(gesture.cancel(), isTrue);
    expect(gesture.candidate, isNull);
    expect(gesture.cancel(), isFalse);
  });

  test('place refines grid Y to exact validated terrain contact', () {
    final gesture = ChunkPrefabSceneGesture();
    final prefab = _prefab(
      collisionShapes: <TerrainSourceShapeDef>[
        _rectangle('body', -10, -20, 10, 0),
      ],
    );
    final chunk = _chunk(
      collisionShapes: <TerrainSourceShapeDef>[
        _rectangle('ground', 0, 100, 320, 180),
      ],
    );
    final expansion = expandChunkV2Collision(
      chunk: chunk,
      prefabs: <PrefabV3Def>[prefab],
      sourcePath: 'chunk.json',
    ).expansion!;

    gesture.beginPlace(
      pointer: 4,
      worldPoint: const Offset(64, 96),
      chunk: chunk,
      prefab: prefab,
      surfaceSnapContext: ChunkPrefabSurfaceSnapContext.fromGeometry(
        geometry: expansion.geometry,
      ),
      surfaceSnapRadiusWorld: 8,
      surfaceSnapEnabled: true,
    );

    expect(gesture.candidate?.x, 64);
    expect(gesture.candidate?.y, 100);
    expect(gesture.isSurfaceSnapped, isTrue);
    expect(gesture.previewCollisionLoops, hasLength(1));

    final result = gesture.finish(pointer: 4, worldPoint: const Offset(64, 96));
    expect(result?.commit?.after.prefabs.single.y, 100);
    expect(result?.commit?.after.prefabs.single.y, isA<int>());
  });
}

PrefabV3Def _prefab({
  List<TerrainSourceShapeDef> collisionShapes = const <TerrainSourceShapeDef>[],
}) => PrefabV3Def(
  prefabKey: 'rock',
  id: 'rock',
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.decoration,
  visualSource: const PrefabVisualSource.atlasSlice('rock'),
  anchorXPx: 8,
  anchorYPx: 8,
  collisionShapes: collisionShapes,
  tags: const [],
);

ChunkV2FileData _chunk({
  List<PlacedPrefabDef> prefabs = const <PlacedPrefabDef>[],
  List<TerrainSourceShapeDef> collisionShapes = const <TerrainSourceShapeDef>[],
}) => ChunkV2FileData(
  chunkKey: 'forest',
  id: 'forest',
  revision: 1,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 320,
  height: 180,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>[],
  tileLayers: const <TileLayerDef>[],
  prefabs: prefabs,
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: collisionShapes,
);

TerrainSourceShapeDef _rectangle(
  String id,
  int left,
  int top,
  int right,
  int bottom,
) => TerrainSourceShapeDef(
  shapeId: id,
  vertices: <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: left * 2, yHalfPixels: top * 2),
    TerrainSourceVertexDef(xHalfPixels: right * 2, yHalfPixels: top * 2),
    TerrainSourceVertexDef(xHalfPixels: right * 2, yHalfPixels: bottom * 2),
    TerrainSourceVertexDef(xHalfPixels: left * 2, yHalfPixels: bottom * 2),
  ],
);
