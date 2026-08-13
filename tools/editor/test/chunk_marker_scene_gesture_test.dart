import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_marker_scene_gesture.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';

void main() {
  test('place preview uses marker defaults and integer half-tie policy', () {
    final gesture = ChunkMarkerSceneGesture();
    final chunk = _chunk();

    gesture.beginPlace(
      pointer: 1,
      worldPoint: const Offset(10.5, -2.5),
      chunk: chunk,
      markerId: 'grojib',
    );
    expect(gesture.candidate?.x, 11);
    expect(gesture.candidate?.y, -3);
    expect(gesture.candidate?.chancePercent, 100);
    expect(gesture.candidate?.salt, 0);
    expect(gesture.candidate?.placement, markerPlacementGround);
    expect(chunk.markers, isEmpty);

    final result = gesture.finish(
      pointer: 1,
      worldPoint: const Offset(20.5, 30.5),
    );
    expect(result?.candidate.x, 21);
    expect(result?.candidate.y, 31);
    expect(result?.commit?.after.markers.single, result?.candidate);
  });

  for (final mode in const <String>[
    markerPlacementGround,
    markerPlacementHighestSurfaceAtX,
    markerPlacementObstacleTop,
  ]) {
    test('move preserves $mode semantics and creates one replacement', () {
      final marker = PlacedMarkerDef(
        markerId: 'hashash',
        x: 20,
        y: 10,
        chancePercent: 75,
        salt: 4,
        placement: mode,
      );
      final chunk = _chunk(markers: <PlacedMarkerDef>[marker]);
      final selection = buildChunkPlacedMarkerSelections(chunk.markers).single;
      final gesture = ChunkMarkerSceneGesture();

      gesture.beginMove(
        pointer: 2,
        worldPoint: const Offset(22, 11),
        chunk: chunk,
        selection: selection,
      );
      final result = gesture.finish(
        pointer: 2,
        worldPoint: const Offset(32.5, 21.5),
      );

      expect(result?.candidate.x, 31);
      expect(result?.candidate.y, 21);
      expect(result?.candidate.chancePercent, 75);
      expect(result?.candidate.salt, 4);
      expect(result?.candidate.placement, mode);
      expect(result?.commit?.before.markers.single, marker);
    });
  }

  test('zero-distance move is a no-op and cancel drops its preview', () {
    const marker = PlacedMarkerDef(markerId: 'grojib', x: 20, y: 10);
    final chunk = _chunk(markers: const <PlacedMarkerDef>[marker]);
    final selection = buildChunkPlacedMarkerSelections(chunk.markers).single;
    final gesture = ChunkMarkerSceneGesture();

    gesture.beginMove(
      pointer: 3,
      worldPoint: const Offset(20, 10),
      chunk: chunk,
      selection: selection,
    );
    expect(
      gesture.finish(pointer: 3, worldPoint: const Offset(20, 10))?.commit,
      isNull,
    );
    gesture.beginMove(
      pointer: 4,
      worldPoint: const Offset(20, 10),
      chunk: chunk,
      selection: selection,
    );
    expect(gesture.cancel(), isTrue);
    expect(gesture.candidate, isNull);
  });
}

ChunkV2FileData _chunk({
  List<PlacedMarkerDef> markers = const <PlacedMarkerDef>[],
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
  prefabs: const <PlacedPrefabDef>[],
  markers: markers,
  groundBandZIndex: 0,
  collisionShapes: const [],
);
