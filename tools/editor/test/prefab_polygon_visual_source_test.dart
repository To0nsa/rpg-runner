import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_polygon_visual_source.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_visual_alpha_mask_loader.dart';
import 'package:runner_editor/src/app/pages/shared/editor_scene_view_utils.dart';
import 'package:runner_editor/src/prefabs/collision_fitting/prefab_collision_fitting.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  test('fit-mask boundary omits edges shared by visible pixels', () {
    final mask = PrefabAlphaMask(
      width: 3,
      height: 2,
      alpha: Uint8List.fromList(const <int>[255, 255, 0, 255, 0, 255]),
    );

    final segments = prefabFitMaskBoundarySegments(
      mask: mask,
      originPx: const Offset(10, 20),
    ).toSet();

    expect(
      segments,
      containsAll(<PrefabFitMaskBoundarySegment>{
        (startPx: const Offset(10, 20), endPx: const Offset(11, 20)),
        (startPx: const Offset(11, 20), endPx: const Offset(12, 20)),
        (startPx: const Offset(10, 22), endPx: const Offset(10, 21)),
        (startPx: const Offset(13, 21), endPx: const Offset(13, 22)),
      }),
    );
    expect(
      segments,
      isNot(
        contains((startPx: const Offset(11, 20), endPx: const Offset(11, 21))),
      ),
    );
    expect(segments, hasLength(12));
  });

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

  test(
    'equivalent projections compare by layout instead of object identity',
    () {
      PrefabPolygonVisualProjection projection({int x = 0}) =>
          PrefabPolygonVisualProjection(
            visualBoundsPx: const Rect.fromLTWH(-2, -3, 4, 5),
            tiles: <PrefabPolygonVisualTile>[
              PrefabPolygonVisualTile(
                sourceId: 'slice',
                destinationRectPx: const Rect.fromLTWH(-2, -3, 4, 5),
                slice: AtlasSliceDef(
                  id: 'slice',
                  sourceImagePath: 'assets/atlas.png',
                  x: x,
                  y: 0,
                  width: 4,
                  height: 5,
                ),
              ),
            ],
          );

      expect(projection().hasSameLayoutAs(projection()), isTrue);
      expect(projection().hasSameLayoutAs(projection(x: 1)), isFalse);
    },
  );

  testWidgets('atlas fitting crops alpha and refreshes digest-bound cache', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('prefab-mask-');
    addTearDown(() => root.deleteSync(recursive: true));
    final assetDirectory = Directory('${root.path}/assets')..createSync();
    final file = File('${assetDirectory.path}/atlas.png');
    file.writeAsBytesSync(
      _png(<List<int>>[
        <int>[0, 0, 0],
        <int>[0, 255, 0],
      ]),
    );
    final projection = PrefabPolygonVisualProjection(
      visualBoundsPx: const Rect.fromLTWH(-1, -1, 2, 2),
      tiles: const <PrefabPolygonVisualTile>[
        PrefabPolygonVisualTile(
          sourceId: 'slice',
          destinationRectPx: Rect.fromLTWH(-1, -1, 2, 2),
          slice: AtlasSliceDef(
            id: 'slice',
            sourceImagePath: 'assets/atlas.png',
            x: 1,
            y: 0,
            width: 2,
            height: 2,
          ),
        ),
      ],
    );
    final cache = EditorUiImageCache();
    final maskCache = PrefabVisualAlphaMaskCache();
    addTearDown(cache.dispose);

    final first = (await tester.runAsync(
      () => PrefabVisualAlphaMaskLoader.load(
        workspaceRootPath: root.path,
        projection: projection,
        imageCache: cache,
        maskCache: maskCache,
      ),
    ))!;
    expect(first.accepted, isTrue);
    expect(first.mask!.alpha, <int>[0, 0, 255, 0]);
    final firstRevision = cache.revision;
    final unchanged = (await tester.runAsync(
      () => PrefabVisualAlphaMaskLoader.load(
        workspaceRootPath: root.path,
        projection: projection,
        imageCache: cache,
        maskCache: maskCache,
      ),
    ))!;
    expect(unchanged.sourceIdentity, first.sourceIdentity);
    expect(identical(unchanged.mask, first.mask), isTrue);
    expect(maskCache.length, 1);
    expect(cache.revision, firstRevision);

    file.writeAsBytesSync(
      _png(<List<int>>[
        <int>[0, 255, 255],
        <int>[0, 255, 0],
      ]),
    );
    final second = (await tester.runAsync(
      () => PrefabVisualAlphaMaskLoader.load(
        workspaceRootPath: root.path,
        projection: projection,
        imageCache: cache,
        maskCache: maskCache,
      ),
    ))!;
    expect(second.accepted, isTrue);
    expect(second.sourceIdentity, isNot(first.sourceIdentity));
    expect(second.mask!.alpha, <int>[255, 255, 255, 0]);
    expect(maskCache.length, 2);
  });

  testWidgets('fitting blocks oversized normalized visuals before loading', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('prefab-mask-budget-');
    addTearDown(() => root.deleteSync(recursive: true));
    final cache = EditorUiImageCache();
    addTearDown(cache.dispose);
    final result = (await tester.runAsync(
      () => PrefabVisualAlphaMaskLoader.load(
        workspaceRootPath: root.path,
        projection: PrefabPolygonVisualProjection(
          visualBoundsPx: Rect.fromLTWH(
            0,
            0,
            PrefabAlphaMask.maximumPixelCount + 1,
            1,
          ),
          tiles: const <PrefabPolygonVisualTile>[],
        ),
        imageCache: cache,
      ),
    ))!;

    expect(result.accepted, isFalse);
    expect(result.diagnostics.single, contains('safety limit'));
  });

  testWidgets('fitting rejects visual sources outside the workspace', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('prefab-mask-boundary-');
    addTearDown(() => root.deleteSync(recursive: true));
    final cache = EditorUiImageCache();
    addTearDown(cache.dispose);
    final result = (await tester.runAsync(
      () => PrefabVisualAlphaMaskLoader.load(
        workspaceRootPath: root.path,
        projection: PrefabPolygonVisualProjection(
          visualBoundsPx: const Rect.fromLTWH(0, 0, 1, 1),
          tiles: const <PrefabPolygonVisualTile>[
            PrefabPolygonVisualTile(
              sourceId: 'escape',
              destinationRectPx: Rect.fromLTWH(0, 0, 1, 1),
              slice: AtlasSliceDef(
                id: 'escape',
                sourceImagePath: '../outside.png',
                x: 0,
                y: 0,
                width: 1,
                height: 1,
              ),
            ),
          ],
        ),
        imageCache: cache,
      ),
    ))!;

    expect(result.accepted, isFalse);
    expect(result.diagnostics.single, contains('outside the workspace'));
  });

  testWidgets('module fitting composites overlapping alpha in cell order', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('prefab-mask-module-');
    addTearDown(() => root.deleteSync(recursive: true));
    final assetDirectory = Directory('${root.path}/assets')..createSync();
    File('${assetDirectory.path}/atlas.png').writeAsBytesSync(
      _png(<List<int>>[
        <int>[128, 128],
      ]),
    );
    final projection = PrefabPolygonVisualProjection(
      visualBoundsPx: const Rect.fromLTWH(0, 0, 1, 1),
      tiles: const <PrefabPolygonVisualTile>[
        PrefabPolygonVisualTile(
          sourceId: 'a',
          destinationRectPx: Rect.fromLTWH(0, 0, 1, 1),
          slice: AtlasSliceDef(
            id: 'a',
            sourceImagePath: 'assets/atlas.png',
            x: 0,
            y: 0,
            width: 1,
            height: 1,
          ),
        ),
        PrefabPolygonVisualTile(
          sourceId: 'b',
          destinationRectPx: Rect.fromLTWH(0, 0, 1, 1),
          slice: AtlasSliceDef(
            id: 'b',
            sourceImagePath: 'assets/atlas.png',
            x: 1,
            y: 0,
            width: 1,
            height: 1,
          ),
        ),
      ],
    );
    final cache = EditorUiImageCache();
    addTearDown(cache.dispose);
    final result = (await tester.runAsync(
      () => PrefabVisualAlphaMaskLoader.load(
        workspaceRootPath: root.path,
        projection: projection,
        imageCache: cache,
      ),
    ))!;

    expect(result.accepted, isTrue);
    expect(result.mask!.alpha.single, 192);
  });
}

List<int> _png(List<List<int>> alphaRows) {
  final raster = image.Image(
    width: alphaRows.first.length,
    height: alphaRows.length,
    numChannels: 4,
  );
  for (var y = 0; y < alphaRows.length; y += 1) {
    for (var x = 0; x < alphaRows[y].length; x += 1) {
      raster.setPixelRgba(x, y, 255, 255, 255, alphaRows[y][x]);
    }
  }
  return image.encodePng(raster);
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
