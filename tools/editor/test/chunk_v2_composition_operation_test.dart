import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_composition_operation.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';

void main() {
  test('operation captures owner revision and complete before snapshot', () {
    final chunk = _chunk();
    final operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: 1,
      presentationKey: 'prefab_rock|10|10|1',
    );

    expect(operation.expectedChunkKey, chunk.chunkKey);
    expect(operation.expectedRevision, chunk.revision);
    expect(operation.before.tileLayers, chunk.tileLayers);
    expect(operation.before.prefabs, chunk.prefabs);
    expect(operation.before.markers, chunk.markers);
    expect(operation.sourceIndex, 1);
    expect(operation.presentationKey, 'prefab_rock|10|10|1');
  });

  test('prefab operations target the captured canonical source index', () {
    final chunk = _chunk();
    final moved = chunk.prefabs[1].copyWith(x: 30);
    final replace = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: 1,
    ).buildPrefab(candidate: moved)!;

    expect(replace.before.prefabs, hasLength(2));
    expect(replace.after.prefabs, hasLength(2));
    expect(replace.after.prefabs[0], same(chunk.prefabs[0]));
    expect(replace.after.prefabs[1].x, 30);

    final added = const PlacedPrefabDef(
      prefabId: 'shrub',
      prefabKey: 'prefab_shrub',
      x: 5,
      y: 5,
      zIndex: -1,
    );
    final add = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
    ).buildPrefab(candidate: added)!;
    expect(add.after.prefabs.first, added);

    final delete = ChunkV2CompositionOperation.delete(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: 0,
    ).buildPrefab()!;
    expect(delete.after.prefabs, <PlacedPrefabDef>[chunk.prefabs[1]]);
  });

  test('marker operations distinguish colocated records by source index', () {
    final chunk = _chunk();
    final edited = chunk.markers[1].copyWith(chancePercent: 75);
    final replace = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
      sourceIndex: 1,
      presentationKey: 'derf|20|5|1',
    ).buildMarker(candidate: edited)!;

    expect(replace.after.markers, hasLength(2));
    expect(
      replace.after.markers
          .singleWhere((marker) => marker.salt == 1)
          .chancePercent,
      100,
    );
    expect(
      replace.after.markers
          .singleWhere((marker) => marker.salt == 2)
          .chancePercent,
      75,
    );

    final added = const PlacedMarkerDef(markerId: 'grojib', x: 5, y: 1);
    final add = ChunkV2CompositionOperation.add(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
    ).buildMarker(candidate: added)!;
    expect(add.after.markers.first, added);

    final delete = ChunkV2CompositionOperation.delete(
      chunk: chunk,
      target: ChunkV2CompositionTarget.markers,
      sourceIndex: 1,
    ).buildMarker()!;
    expect(delete.after.markers, <PlacedMarkerDef>[chunk.markers[0]]);
  });

  test('semantic no-op closes locally without constructing a command', () {
    final chunk = _chunk();
    final operation = ChunkV2CompositionOperation.replace(
      chunk: chunk,
      target: ChunkV2CompositionTarget.prefabs,
      sourceIndex: 0,
    );

    expect(operation.buildPrefab(candidate: chunk.prefabs[0]), isNull);
  });

  test('selection recomputation requires one full-equality match', () {
    final chunk = _chunk();
    final acceptedPrefab = chunk.prefabs.singleWhere(
      (prefab) => prefab.zIndex == 2,
    );
    final acceptedMarker = chunk.markers.singleWhere(
      (marker) => marker.salt == 2,
    );

    expect(
      uniqueChunkPrefabSelectionKey(chunk.prefabs, acceptedPrefab),
      'prefab_rock|10|10|1',
    );
    expect(
      uniqueChunkMarkerSelectionKey(chunk.markers, acceptedMarker),
      'derf|20|5|1',
    );
    expect(
      uniqueChunkPrefabSelectionKey(<PlacedPrefabDef>[
        acceptedPrefab,
        acceptedPrefab,
      ], acceptedPrefab),
      isNull,
    );
    expect(
      uniqueChunkMarkerSelectionKey(<PlacedMarkerDef>[
        acceptedMarker,
        acceptedMarker,
      ], acceptedMarker),
      isNull,
    );
    expect(
      resolveChunkPrefabSelection(
        chunk.prefabs,
        'prefab_rock|10|10|1',
      )?.sourceIndex,
      1,
    );
    expect(
      resolveChunkPrefabSelection(chunk.prefabs, 'prefab_rock|11|10|1'),
      isNull,
    );
    expect(
      resolveChunkMarkerSelection(chunk.markers, 'derf|20|5|1')?.sourceIndex,
      1,
    );
    expect(resolveChunkMarkerSelection(chunk.markers, 'derf|21|5|1'), isNull);
  });
}

ChunkV2FileData _chunk() => ChunkV2FileData(
  chunkKey: 'forest_target',
  id: 'forest_target',
  revision: 7,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 100,
  height: 50,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: <String>['forest'],
  tileLayers: <TileLayerDef>[TileLayerDef(id: 'background')],
  prefabs: <PlacedPrefabDef>[
    PlacedPrefabDef(prefabId: 'rock', prefabKey: 'prefab_rock', x: 10, y: 10),
    PlacedPrefabDef(
      prefabId: 'rock',
      prefabKey: 'prefab_rock',
      x: 10,
      y: 10,
      zIndex: 2,
    ),
  ],
  markers: <PlacedMarkerDef>[
    PlacedMarkerDef(markerId: 'derf', x: 20, y: 5, salt: 1),
    PlacedMarkerDef(markerId: 'derf', x: 20, y: 5, salt: 2),
  ],
  groundBandZIndex: 0,
  collisionShapes: <Never>[],
);
