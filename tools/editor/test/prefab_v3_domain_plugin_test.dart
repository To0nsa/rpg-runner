import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/prefabs/store/prefab_v3_file_codec.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_polygon_interaction.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  const plugin = PrefabDomainPlugin();

  test(
    'staged command commits through owner policy and builds pending diff',
    () {
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final after = <TerrainSourceShapeDef>[_rectangle(right: 10)];
      final document = _document(before);

      expect(plugin.validate(document), isEmpty);
      expect(plugin.buildEditableScene(document), isA<PrefabV3StagingScene>());
      final edited = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(before: before, after: after),
          },
        ),
      );

      expect(edited, isA<PrefabV3StagingDocument>());
      final next = edited as PrefabV3StagingDocument;
      expect(next, isNot(same(document)));
      expect(document.data.prefabs.single.revision, 4);
      expect(next.data.prefabs.single.revision, 5);
      expect(next.data.prefabs.single.collisionShapes, after);
      expect(next.changedPrefabKeys, <String>['target']);

      final pending = plugin.describePendingChanges(
        EditorWorkspace(rootPath: Directory.current.path),
        document: next,
      );
      expect(pending.hasChanges, isTrue);
      expect(pending.changedItemIds, <String>['target']);
      expect(pending.fileDiffs, hasLength(1));
      expect(
        pending.fileDiffs.single.relativePath,
        contains('prefab_defs.json'),
      );
      expect(pending.fileDiffs.single.unifiedDiff, contains('collisionShapes'));
    },
  );

  test(
    'invalid topology, stale, malformed, and no-op commands keep identity',
    () {
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final document = _document(before);
      final invalid = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_selfIntersectingShape()],
            ),
          },
        ),
      );
      final stale = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: <TerrainSourceShapeDef>[_rectangle(left: -6, right: 8)],
              after: before,
            ),
          },
        ),
      );
      final malformed = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: const <String, Object?>{'prefabKey': 'target'},
        ),
      );
      final noOp = plugin.applyEdit(
        document,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(before: before, after: before),
          },
        ),
      );

      expect(invalid, same(document));
      expect(stale, same(document));
      expect(malformed, same(document));
      expect(noOp, same(document));
    },
  );

  test('staged export is a no-op when clean and locked when changed', () async {
    final root = Directory.systemTemp.createTempSync('prefab_v3_plugin_');
    try {
      final before = <TerrainSourceShapeDef>[_rectangle(right: 8)];
      final clean = _document(before);
      final workspace = EditorWorkspace(rootPath: root.path);
      final cleanResult = await plugin.exportToRepo(workspace, document: clean);
      expect(cleanResult.applied, isFalse);
      expect(cleanResult.artifacts.single.content, contains('changedFiles: 0'));

      final changed = plugin.applyEdit(
        clean,
        AuthoringCommand(
          kind: PrefabDomainPlugin.commitPrefabPolygonCommandKind,
          payload: <String, Object?>{
            'prefabKey': 'target',
            'commit': _commit(
              before: before,
              after: <TerrainSourceShapeDef>[_rectangle(right: 10)],
            ),
          },
        ),
      );
      await expectLater(
        plugin.exportToRepo(workspace, document: changed),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('prefab_v3_source_write_disabled'),
          ),
        ),
      );
      expect(root.listSync(recursive: true), isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('staged validation reports unresolved visual owner bounds', () {
    final source = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final unresolved = source.copyWith(
      visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{},
    );

    final issues = plugin.validate(unresolved);

    expect(issues, hasLength(1));
    expect(issues.single.severity, ValidationSeverity.error);
    expect(issues.single.code, 'prefab_polygon_visual_bounds_unresolved');
  });
}

PrefabV3StagingDocument _document(Iterable<TerrainSourceShapeDef> shapes) {
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[],
    prefabs: <PrefabV3Def>[
      PrefabV3Def(
        prefabKey: 'target',
        id: 'target',
        revision: 4,
        status: PrefabStatus.active,
        kind: PrefabKind.obstacle,
        visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
        anchorXPx: 5,
        anchorYPx: 5,
        collisionShapes: shapes,
        tags: const <String>['test'],
      ),
    ],
  );
  return PrefabV3StagingDocument(
    data: data,
    tileData: PrefabTileFileData(
      tileSlices: const <AtlasSliceDef>[],
      platformModules: const <TileModuleDef>[],
    ),
    visualBoundsByPrefabKey: const <String, PrefabV3VisualBounds>{
      'target': PrefabV3VisualBounds(widthPx: 10, heightPx: 10),
    },
    atlasImagePaths: const <String>[],
    atlasImageSizes: const <String, Size>{},
    prefabBaselineContents: PrefabV3FileCodec.encode(data),
    tileBaselineContents: null,
  );
}

TerrainPolygonInteractionCommit _commit({
  required Iterable<TerrainSourceShapeDef> before,
  required Iterable<TerrainSourceShapeDef> after,
}) => TerrainPolygonInteractionCommit(
  beforeShapes: before,
  afterShapes: after,
  beforeSelection: null,
  afterSelection: null,
);

TerrainSourceShapeDef _rectangle({int left = -8, required int right}) =>
    TerrainSourceShapeDef(
      shapeId: 'collision_001',
      vertices: <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: -8),
        TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: -8),
        TerrainSourceVertexDef(xHalfPixels: right, yHalfPixels: 8),
        TerrainSourceVertexDef(xHalfPixels: left, yHalfPixels: 8),
      ],
    );

TerrainSourceShapeDef _selfIntersectingShape() => TerrainSourceShapeDef(
  shapeId: 'collision_001',
  vertices: const <TerrainSourceVertexDef>[
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: 8),
    TerrainSourceVertexDef(xHalfPixels: 8, yHalfPixels: -8),
    TerrainSourceVertexDef(xHalfPixels: -8, yHalfPixels: 8),
  ],
);
