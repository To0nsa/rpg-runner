import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/chunks/chunk_store.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_codec.dart';
import 'package:runner_editor/src/chunks/chunk_v2_file_data.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_store.dart';
import 'package:runner_editor/src/prefabs/store/prefab_tile_file_codec.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  const store = PrefabStore();
  const plugin = PrefabDomainPlugin();

  test('normal plugin load selects strict prefab-v3 source', () async {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);

    expect(
      store.detectSourceGeneration(fixture.root.path),
      PrefabSourceGeneration.currentV3,
    );
    final document = await plugin.loadFromRepo(fixture.workspace);

    expect(document, isA<PrefabV3StagingDocument>());
    expect(plugin.validate(document), isEmpty);
    expect(plugin.buildEditableScene(document), isA<PrefabV3StagingScene>());
    expect(
      plugin
          .describePendingChanges(fixture.workspace, document: document)
          .hasChanges,
      isFalse,
    );
  });

  test(
    'explicit staging load strictly composes prefab, tile, bounds, and atlas metadata',
    () async {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);

      final document = await plugin.loadV3StagingFromRepo(fixture.workspace);

      expect(document.data.prefabs, hasLength(2));
      expect(document.tileData.platformModules.single.id, 'module_a');
      expect(
        document.visualBoundsByPrefabKey['obstacle'],
        isA<PrefabV3VisualBounds>()
            .having((bounds) => bounds.widthPx, 'widthPx', 10)
            .having((bounds) => bounds.heightPx, 'heightPx', 12),
      );
      expect(
        document.visualBoundsByPrefabKey['platform'],
        isA<PrefabV3VisualBounds>()
            .having((bounds) => bounds.widthPx, 'widthPx', 64)
            .having((bounds) => bounds.heightPx, 'heightPx', 24),
      );
      expect(document.atlasImagePaths, <String>[
        'assets/images/level/test.png',
      ]);
      expect(
        document.atlasImageSizes['assets/images/level/test.png'],
        const Size(64, 32),
      );
      expect(document.prefabBaselineContents, fixture.prefabContents);
      expect(document.tileBaselineContents, fixture.tileContents);
      expect(
        document.downstreamImpacts.map((impact) => impact.prefabKey),
        <String>['obstacle', 'platform'],
      );
      expect(
        document.downstreamImpacts.every(
          (impact) =>
              impact.placementCount == 0 && impact.referencingChunkKeys.isEmpty,
        ),
        isTrue,
      );
      expect(plugin.validate(document), isEmpty);

      final scene = plugin.buildEditableScene(document);
      expect(scene, isA<PrefabV3StagingScene>());
      final stagingScene = scene as PrefabV3StagingScene;
      expect(stagingScene.tileData.platformModules.single.id, 'module_a');
      expect(stagingScene.atlasImagePaths, document.atlasImagePaths);
      expect(stagingScene.atlasImageSizes, document.atlasImageSizes);
      expect(
        plugin
            .describePendingChanges(fixture.workspace, document: document)
            .hasChanges,
        isFalse,
      );
      expect(
        () => document.atlasImagePaths.add('external.png'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'staging load reports deterministic downstream placement impact without writes',
    () async {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.writeChunk(
        _chunk(
          chunkKey: 'forest_b',
          revision: 8,
          prefabs: const <PlacedPrefabDef>[
            PlacedPrefabDef(
              prefabId: 'obstacle',
              prefabKey: 'obstacle',
              x: 20,
              y: 0,
            ),
            PlacedPrefabDef(prefabId: 'platform', x: 40, y: 0),
          ],
        ),
      );
      fixture.writeChunk(
        _chunk(
          chunkKey: 'forest_a',
          revision: 3,
          prefabs: const <PlacedPrefabDef>[
            PlacedPrefabDef(
              prefabId: 'renamed_obstacle',
              prefabKey: 'obstacle',
              x: 0,
              y: 0,
            ),
            PlacedPrefabDef(prefabId: 'obstacle', x: 10, y: 0),
          ],
        ),
      );
      final before = fixture.snapshot();

      final document = await plugin.loadV3StagingFromRepo(fixture.workspace);

      expect(document.downstreamImpacts, hasLength(2));
      expect(
        document.downstreamImpacts.first,
        isA<PrefabV3DownstreamImpact>()
            .having((impact) => impact.prefabKey, 'prefabKey', 'obstacle')
            .having((impact) => impact.placementCount, 'placementCount', 3)
            .having(
              (impact) => impact.referencingChunkKeys,
              'referencingChunkKeys',
              <String>['forest_a', 'forest_b'],
            ),
      );
      expect(
        document.downstreamImpacts.last,
        isA<PrefabV3DownstreamImpact>()
            .having((impact) => impact.prefabKey, 'prefabKey', 'platform')
            .having((impact) => impact.placementCount, 'placementCount', 1)
            .having(
              (impact) => impact.referencingChunkKeys,
              'referencingChunkKeys',
              <String>['forest_b'],
            ),
      );
      expect(fixture.snapshot(), before);
    },
  );

  test('staging load and clean export never mutate fixture source', () async {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    final before = fixture.snapshot();

    final document = await plugin.loadV3StagingFromRepo(fixture.workspace);
    final result = await plugin.exportToRepo(
      fixture.workspace,
      document: document,
    );

    expect(result.applied, isFalse);
    expect(fixture.snapshot(), before);
  });

  test('changed normal prefab-v3 export applies and reloads exactly', () async {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    final loaded = await plugin.loadFromRepo(fixture.workspace);
    final document = loaded as PrefabV3StagingDocument;
    final target = document.data.prefabs.first;
    final editedTarget = target.copyWith(
      revision: target.revision + 1,
      tags: const <String>['exported'],
    );
    final changed = document.copyWith(
      data: document.data.copyWith(
        prefabs: <PrefabV3Def>[editedTarget, ...document.data.prefabs.skip(1)],
      ),
      changedPrefabKeys: <String>[target.prefabKey],
    );

    final result = await plugin.exportToRepo(
      fixture.workspace,
      document: changed,
    );

    expect(result.applied, isTrue);
    expect(
      fixture.prefabFile.readAsStringSync(),
      PrefabV3FileCodec.encode(changed.data),
    );
    final reloaded = await plugin.loadFromRepo(fixture.workspace);
    expect(reloaded, isA<PrefabV3StagingDocument>());
    expect(
      (reloaded as PrefabV3StagingDocument).data.prefabs.first.tags,
      <String>['exported'],
    );
  });

  test(
    'staging store rejects legacy prefab source and a missing tile file',
    () async {
      final fixture = _Fixture.create();
      addTearDown(fixture.dispose);
      fixture.prefabFile.writeAsStringSync(
        fixture.prefabContents.replaceFirst(
          '"schemaVersion": 3',
          '"schemaVersion": 2',
        ),
      );

      await expectLater(
        store.loadV3Staging(fixture.root.path),
        throwsFormatException,
      );

      fixture.prefabFile.writeAsStringSync(fixture.prefabContents);
      fixture.tileFile.deleteSync();
      await expectLater(
        store.loadV3Staging(fixture.root.path),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('prefab_tile_source_missing'),
          ),
        ),
      );
    },
  );

  test('normal generation detection rejects unsupported prefab schemas', () {
    final fixture = _Fixture.create();
    addTearDown(fixture.dispose);
    fixture.prefabFile.writeAsStringSync(
      fixture.prefabContents.replaceFirst(
        '"schemaVersion": 3',
        '"schemaVersion": 4',
      ),
    );

    expect(
      () => store.detectSourceGeneration(fixture.root.path),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported prefab schemaVersion 4'),
        ),
      ),
    );
  });
}

final class _Fixture {
  _Fixture._({
    required this.root,
    required this.prefabContents,
    required this.tileContents,
  });

  factory _Fixture.create() {
    final root = Directory.systemTemp.createTempSync('prefab_v3_staging_load_');
    final prefabData = PrefabV3FileData(
      slices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'obstacle_slice',
          sourceImagePath: 'assets/images/level/test.png',
          x: 0,
          y: 0,
          width: 10,
          height: 12,
        ),
      ],
      prefabs: <PrefabV3Def>[
        PrefabV3Def(
          prefabKey: 'obstacle',
          id: 'obstacle',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: const PrefabVisualSource.atlasSlice('obstacle_slice'),
          anchorXPx: 5,
          anchorYPx: 6,
          collisionShapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
          tags: const <String>[],
        ),
        PrefabV3Def(
          prefabKey: 'platform',
          id: 'platform',
          revision: 2,
          status: PrefabStatus.active,
          kind: PrefabKind.platform,
          visualSource: const PrefabVisualSource.platformModule('module_a'),
          anchorXPx: 32,
          anchorYPx: 12,
          collisionShapes: <TerrainSourceShapeDef>[_rectangle('collision_001')],
          tags: const <String>[],
        ),
      ],
    );
    final tileData = PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'tile_a',
          sourceImagePath: 'assets/images/level/test.png',
          x: 0,
          y: 12,
          width: 16,
          height: 16,
        ),
        AtlasSliceDef(
          id: 'tile_b',
          sourceImagePath: 'assets/images/level/test.png',
          x: 16,
          y: 12,
          width: 32,
          height: 8,
        ),
      ],
      platformModules: const <TileModuleDef>[
        TileModuleDef(
          id: 'module_a',
          revision: 1,
          status: TileModuleStatus.active,
          tileSize: 16,
          cells: <TileModuleCellDef>[
            TileModuleCellDef(sliceId: 'tile_a', gridX: -1, gridY: 0),
            TileModuleCellDef(sliceId: 'tile_b', gridX: 1, gridY: 1),
          ],
        ),
      ],
    );
    final prefabContents = PrefabV3FileCodec.encode(prefabData);
    final tileContents = PrefabTileFileCodec.encode(tileData);
    final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath))
      ..createSync(recursive: true);
    prefabFile.writeAsStringSync(prefabContents);
    final tileFile = File(p.join(root.path, PrefabStore.tileDefsPath))
      ..createSync(recursive: true);
    tileFile.writeAsStringSync(tileContents);
    final imageFile = File(p.join(root.path, 'assets/images/level/test.png'))
      ..createSync(recursive: true);
    imageFile.writeAsBytesSync(_pngHeader(width: 64, height: 32));
    return _Fixture._(
      root: root,
      prefabContents: prefabContents,
      tileContents: tileContents,
    );
  }

  final Directory root;
  final String prefabContents;
  final String tileContents;

  EditorWorkspace get workspace => EditorWorkspace(rootPath: root.path);
  File get prefabFile => File(p.join(root.path, PrefabStore.prefabDefsPath));
  File get tileFile => File(p.join(root.path, PrefabStore.tileDefsPath));

  void writeChunk(ChunkV2FileData chunk) {
    File(
        p.join(
          root.path,
          ChunkStore.chunksDirectoryPath,
          chunk.levelId,
          '${chunk.chunkKey}.json',
        ),
      )
      ..createSync(recursive: true)
      ..writeAsStringSync(ChunkV2FileCodec.encode(chunk));
  }

  Map<String, List<int>> snapshot() => <String, List<int>>{
    for (final file
        in root.listSync(recursive: true).whereType<File>().toList()
          ..sort((left, right) => left.path.compareTo(right.path)))
      p.relative(file.path, from: root.path): file.readAsBytesSync(),
  };

  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

ChunkV2FileData _chunk({
  required String chunkKey,
  required int revision,
  required List<PlacedPrefabDef> prefabs,
}) => ChunkV2FileData(
  chunkKey: chunkKey,
  id: chunkKey,
  revision: revision,
  status: chunkStatusActive,
  levelId: 'forest',
  tileSize: 16,
  width: 100,
  height: 50,
  difficulty: chunkDifficultyNormal,
  assemblyGroupId: defaultChunkAssemblyGroupId,
  tags: const <String>['forest'],
  tileLayers: const <TileLayerDef>[],
  prefabs: prefabs,
  markers: const <PlacedMarkerDef>[],
  groundBandZIndex: 0,
  collisionShapes: const <TerrainSourceShapeDef>[],
);

TerrainSourceShapeDef _rectangle(String shapeId) => TerrainSourceShapeDef(
  shapeId: shapeId,
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);

Uint8List _pngHeader({required int width, required int height}) {
  final bytes = Uint8List(24);
  bytes.setAll(0, const <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  bytes[16] = (width >> 24) & 0xff;
  bytes[17] = (width >> 16) & 0xff;
  bytes[18] = (width >> 8) & 0xff;
  bytes[19] = width & 0xff;
  bytes[20] = (height >> 24) & 0xff;
  bytes[21] = (height >> 16) & 0xff;
  bytes[22] = (height >> 8) & 0xff;
  bytes[23] = height & 0xff;
  return bytes;
}
