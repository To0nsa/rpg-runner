import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
