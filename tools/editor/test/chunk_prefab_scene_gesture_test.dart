import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_prefab_scene_gesture.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

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
}

PrefabV3Def _prefab() => PrefabV3Def(
  prefabKey: 'rock',
  id: 'rock',
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.decoration,
  visualSource: const PrefabVisualSource.atlasSlice('rock'),
  anchorXPx: 8,
  anchorYPx: 8,
  collisionShapes: const [],
  tags: const [],
);

ChunkV2FileData _chunk({
  List<PlacedPrefabDef> prefabs = const <PlacedPrefabDef>[],
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
  collisionShapes: const [],
);
