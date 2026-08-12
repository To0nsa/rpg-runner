import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_polygon_visual_source.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test('projects placed chunk art in visual stack order', () {
    final projection = ChunkPolygonVisualProjection.fromChunk(
      chunk: ChunkV2FileData(
        chunkKey: 'forest_preview',
        id: 'forest_preview',
        revision: 1,
        status: chunkStatusActive,
        levelId: 'forest',
        tileSize: 16,
        width: 600,
        height: 270,
        difficulty: chunkDifficultyNormal,
        assemblyGroupId: defaultChunkAssemblyGroupId,
        tags: const <String>[],
        tileLayers: const <TileLayerDef>[],
        prefabs: const <PlacedPrefabDef>[
          PlacedPrefabDef(
            prefabId: 'missing',
            prefabKey: 'missing',
            x: 15,
            y: 20,
            zIndex: -1,
          ),
          PlacedPrefabDef(
            prefabId: 'platform',
            prefabKey: 'platform',
            x: 80,
            y: 120,
            zIndex: 0,
          ),
          PlacedPrefabDef(
            prefabId: 'tree',
            prefabKey: 'tree',
            x: 240,
            y: 180,
            zIndex: 2,
            scale: 0.5,
            flipX: true,
          ),
        ],
        markers: const <PlacedMarkerDef>[],
        groundBandZIndex: 0,
        collisionShapes: const [],
      ),
      prefabData: PrefabV3FileData(
        slices: const <AtlasSliceDef>[
          AtlasSliceDef(
            id: 'tree_slice',
            sourceImagePath: 'assets/tree.png',
            x: 4,
            y: 8,
            width: 40,
            height: 60,
          ),
        ],
        prefabs: <PrefabV3Def>[
          _prefab(
            prefabKey: 'tree',
            visualSource: const PrefabVisualSource.atlasSlice('tree_slice'),
            anchorXPx: 12,
            anchorYPx: 50,
          ),
          _prefab(
            prefabKey: 'platform',
            visualSource: const PrefabVisualSource.platformModule('ledge'),
            anchorXPx: 8,
            anchorYPx: 16,
          ),
        ],
      ),
      tileData: PrefabTileFileData(
        tileSlices: const <AtlasSliceDef>[
          AtlasSliceDef(
            id: 'grass',
            sourceImagePath: 'assets/grass.png',
            x: 0,
            y: 0,
            width: 16,
            height: 16,
          ),
        ],
        platformModules: const <TileModuleDef>[
          TileModuleDef(
            id: 'ledge',
            tileSize: 16,
            cells: <TileModuleCellDef>[
              TileModuleCellDef(sliceId: 'grass', gridX: 0, gridY: 0),
              TileModuleCellDef(sliceId: 'grass', gridX: 1, gridY: 0),
            ],
          ),
        ],
      ),
      visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
        'tree': PrefabV3VisualBounds(widthPx: 40, heightPx: 60),
        'platform': PrefabV3VisualBounds(widthPx: 32, heightPx: 16),
      },
    );

    expect(
      projection.placements.map((placement) => placement.placement.prefabKey),
      <String>['missing', 'platform', 'tree'],
    );
    expect(projection.belowTerrain(0).single.visualSource, isNull);
    final placedPlatform = projection.atOrAboveTerrain(0).first;
    expect(placedPlatform.placement.prefabKey, 'platform');
    expect(placedPlatform.visualSource?.tiles, hasLength(2));

    final placedTree = projection.atOrAboveTerrain(0).last;
    expect(placedTree.placement.scale, 0.5);
    expect(placedTree.placement.flipX, isTrue);
    expect(
      placedTree.visualSource?.tiles.single.destinationRectPx,
      const Rect.fromLTWH(-12, -50, 40, 60),
    );
  });
}

PrefabV3Def _prefab({
  required String prefabKey,
  required PrefabVisualSource visualSource,
  required int anchorXPx,
  required int anchorYPx,
}) => PrefabV3Def(
  prefabKey: prefabKey,
  id: prefabKey,
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.decoration,
  visualSource: visualSource,
  anchorXPx: anchorXPx,
  anchorYPx: anchorYPx,
  collisionShapes: const [],
  tags: const <String>[],
);
