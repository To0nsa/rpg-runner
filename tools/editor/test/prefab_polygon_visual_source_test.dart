import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_polygon_visual_source.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('atlas visual source is projected relative to the prefab anchor', () {
    final prefab = _prefab(
      visualSource: const PrefabVisualSource.atlasSlice('obstacle_slice'),
      anchorXPx: 3,
      anchorYPx: 4,
    );
    final document = _document(
      prefab: prefab,
      slices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'obstacle_slice',
          sourceImagePath: 'assets/atlas.png',
          x: 10,
          y: 20,
          width: 10,
          height: 12,
        ),
      ],
      bounds: const PrefabV3VisualBounds(widthPx: 10, heightPx: 12),
    );

    final projection = PrefabPolygonVisualProjection.fromDocument(
      document: document,
      prefab: prefab,
    );

    expect(projection.visualBoundsPx, const Rect.fromLTWH(-3, -4, 10, 12));
    expect(projection.tiles, hasLength(1));
    expect(
      projection.tiles.single.destinationRectPx,
      const Rect.fromLTWH(-3, -4, 10, 12),
    );
    expect(projection.tiles.single.slice?.id, 'obstacle_slice');
  });

  test('negative module cells normalize before applying the prefab anchor', () {
    final prefab = _prefab(
      visualSource: const PrefabVisualSource.platformModule('module_a'),
      anchorXPx: 5,
      anchorYPx: 7,
    );
    final tileSlices = const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'left',
        sourceImagePath: 'assets/tiles.png',
        x: 0,
        y: 0,
        width: 8,
        height: 10,
      ),
      AtlasSliceDef(
        id: 'right',
        sourceImagePath: 'assets/tiles.png',
        x: 8,
        y: 0,
        width: 12,
        height: 12,
      ),
    ];
    final document = _document(
      prefab: prefab,
      tileData: PrefabTileFileData(
        tileSlices: tileSlices,
        platformModules: const <TileModuleDef>[
          TileModuleDef(
            id: 'module_a',
            tileSize: 16,
            cells: <TileModuleCellDef>[
              TileModuleCellDef(sliceId: 'left', gridX: -1, gridY: 0),
              TileModuleCellDef(sliceId: 'right', gridX: 0, gridY: 1),
            ],
          ),
        ],
      ),
      bounds: const PrefabV3VisualBounds(widthPx: 28, heightPx: 28),
    );

    final projection = PrefabPolygonVisualProjection.fromDocument(
      document: document,
      prefab: prefab,
    );

    expect(projection.visualBoundsPx, const Rect.fromLTWH(-5, -7, 28, 28));
    expect(projection.tiles.map((tile) => tile.destinationRectPx), <Rect>[
      const Rect.fromLTWH(-5, -7, 8, 10),
      const Rect.fromLTWH(11, 9, 12, 12),
    ]);
  });
}

PrefabV3Def _prefab({
  required PrefabVisualSource visualSource,
  required int anchorXPx,
  required int anchorYPx,
}) => PrefabV3Def(
  prefabKey: 'owner',
  id: 'owner',
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: visualSource,
  anchorXPx: anchorXPx,
  anchorYPx: anchorYPx,
  collisionShapes: <TerrainSourceShapeDef>[_rectangle()],
  tags: const <String>[],
);

PrefabV3Document _document({
  required PrefabV3Def prefab,
  required PrefabV3VisualBounds bounds,
  Iterable<AtlasSliceDef> slices = const <AtlasSliceDef>[],
  PrefabTileFileData? tileData,
}) => PrefabV3Document(
  data: PrefabV3FileData(slices: slices, prefabs: <PrefabV3Def>[prefab]),
  tileData:
      tileData ??
      PrefabTileFileData(
        tileSlices: const <AtlasSliceDef>[],
        platformModules: const <TileModuleDef>[],
      ),
  visualBoundsByPrefabKey: <String, PrefabV3VisualBounds>{
    prefab.prefabKey: bounds,
  },
  atlasImagePaths: const <String>[],
  atlasImageSizes: const <String, Size>{},
  prefabBaselineContents: null,
  tileBaselineContents: null,
);

TerrainSourceShapeDef _rectangle() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -2, yHalfPixels: -2),
    TerrainSourceVertexDef(xHalfPixels: 2, yHalfPixels: -2),
    TerrainSourceVertexDef(xHalfPixels: 2, yHalfPixels: 2),
    TerrainSourceVertexDef(xHalfPixels: -2, yHalfPixels: 2),
  ],
);
