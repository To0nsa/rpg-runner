import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_lifecycle_commit.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_v3_metadata_commit.dart';
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

  test('typed metadata changes only owner metadata and revision once', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final before = document.data.prefabs.single;
    final edited =
        plugin.applyEdit(
              document,
              AuthoringCommand(
                kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
                payload: <String, Object?>{
                  'prefabKey': before.prefabKey,
                  'commit': PrefabV3MetadataCommit(
                    before: PrefabV3MetadataSnapshot.fromPrefab(before),
                    after: PrefabV3MetadataSnapshot(
                      status: PrefabStatus.deprecated,
                      kind: before.kind,
                      visualSource: before.visualSource,
                      anchorXPx: 4,
                      anchorYPx: 6,
                      tags: const <String>['boss', 'test'],
                    ),
                  ),
                },
              ),
            )
            as PrefabV3StagingDocument;

    final after = edited.data.prefabs.single;
    expect(after.prefabKey, before.prefabKey);
    expect(after.id, before.id);
    expect(after.revision, before.revision + 1);
    expect(after.status, PrefabStatus.deprecated);
    expect(after.anchorXPx, 4);
    expect(after.anchorYPx, 6);
    expect(after.tags, <String>['boss', 'test']);
    expect(after.collisionShapes, before.collisionShapes);
    expect(edited.changedPrefabKeys, <String>['target']);
    expect(plugin.validate(edited), isEmpty);
  });

  test('stale invalid and no-op metadata commands preserve identity', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final current = document.data.prefabs.single;
    final before = PrefabV3MetadataSnapshot.fromPrefab(current);

    AuthoringDocument apply(PrefabV3MetadataCommit commit) => plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3MetadataCommandKind,
        payload: <String, Object?>{
          'prefabKey': current.prefabKey,
          'commit': commit,
        },
      ),
    );

    final stale = PrefabV3MetadataSnapshot(
      status: current.status,
      kind: current.kind,
      visualSource: current.visualSource,
      anchorXPx: 4,
      anchorYPx: current.anchorYPx,
      tags: current.tags,
    );
    final invalidSource = PrefabV3MetadataSnapshot(
      status: current.status,
      kind: current.kind,
      visualSource: const PrefabVisualSource.atlasSlice('missing'),
      anchorXPx: current.anchorXPx,
      anchorYPx: current.anchorYPx,
      tags: current.tags,
    );
    final noncanonicalTags = PrefabV3MetadataSnapshot(
      status: current.status,
      kind: current.kind,
      visualSource: current.visualSource,
      anchorXPx: current.anchorXPx,
      anchorYPx: current.anchorYPx,
      tags: const <String>['test', 'boss'],
    );

    expect(
      apply(PrefabV3MetadataCommit(before: stale, after: invalidSource)),
      same(document),
    );
    expect(
      apply(PrefabV3MetadataCommit(before: before, after: invalidSource)),
      same(document),
    );
    expect(
      apply(PrefabV3MetadataCommit(before: before, after: noncanonicalTags)),
      same(document),
    );
    expect(
      apply(PrefabV3MetadataCommit(before: before, after: before)),
      same(document),
    );
  });

  test(
    'typed lifecycle owns allocation create duplicate rename and delete',
    () {
      final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);

      PrefabV3StagingDocument apply(
        PrefabV3StagingDocument source,
        PrefabV3LifecycleOperation operation,
      ) =>
          plugin.applyEdit(
                source,
                AuthoringCommand(
                  kind: PrefabDomainPlugin.commitPrefabV3LifecycleCommandKind,
                  payload: <String, Object?>{
                    'commit': PrefabV3LifecycleCommit(
                      before: PrefabV3LifecycleSnapshot.fromDocument(source),
                      operation: operation,
                    ),
                  },
                ),
              )
              as PrefabV3StagingDocument;

      final created = apply(
        document,
        PrefabV3CreateOperation(
          id: 'New Decoration',
          kind: PrefabKind.decoration,
          visualSource: const PrefabVisualSource.atlasSlice('slice_a'),
          anchorXPx: 5,
          anchorYPx: 5,
        ),
      );
      final createdOwner = created.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'new_decoration',
      );
      expect(createdOwner.id, 'New Decoration');
      expect(createdOwner.revision, 1);
      expect(createdOwner.status, PrefabStatus.active);
      expect(createdOwner.collisionShapes, isEmpty);

      final duplicated = apply(
        created,
        const PrefabV3DuplicateOperation(sourcePrefabKey: 'target'),
      );
      final duplicate = duplicated.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'target_copy',
      );
      final duplicateSource = created.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'target',
      );
      expect(duplicate.id, 'target_copy');
      expect(duplicate.revision, 1);
      expect(duplicate.collisionShapes, duplicateSource.collisionShapes);

      final renamed = apply(
        duplicated,
        const PrefabV3RenameOperation(
          prefabKey: 'target_copy',
          nextId: 'renamed_target',
        ),
      );
      final renamedOwner = renamed.data.prefabs.singleWhere(
        (prefab) => prefab.prefabKey == 'target_copy',
      );
      expect(renamedOwner.id, 'renamed_target');
      expect(renamedOwner.revision, 2);

      final deleted = apply(
        renamed,
        const PrefabV3DeleteOperation(prefabKey: 'new_decoration'),
      );
      expect(
        deleted.data.prefabs.any(
          (prefab) => prefab.prefabKey == 'new_decoration',
        ),
        isFalse,
      );
      expect(deleted.changedPrefabKeys, <String>[
        'new_decoration',
        'target_copy',
      ]);
      expect(
        plugin
            .describePendingChanges(
              EditorWorkspace(rootPath: Directory.current.path),
              document: deleted,
            )
            .hasChanges,
        isTrue,
      );
    },
  );

  test('stale invalid colliding and missing lifecycle edits keep identity', () {
    final document = _document(<TerrainSourceShapeDef>[_rectangle(right: 8)]);
    final before = PrefabV3LifecycleSnapshot.fromDocument(document);

    AuthoringDocument apply(PrefabV3LifecycleCommit commit) => plugin.applyEdit(
      document,
      AuthoringCommand(
        kind: PrefabDomainPlugin.commitPrefabV3LifecycleCommandKind,
        payload: <String, Object?>{'commit': commit},
      ),
    );

    final staleDocument = document.copyWith(
      data: document.data.copyWith(
        prefabs: <PrefabV3Def>[
          document.data.prefabs.single.copyWith(revision: 5),
        ],
      ),
    );
    final stale = PrefabV3LifecycleSnapshot.fromDocument(staleDocument);
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: stale,
          operation: const PrefabV3RenameOperation(
            prefabKey: 'target',
            nextId: 'renamed',
          ),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: before,
          operation: const PrefabV3RenameOperation(
            prefabKey: 'target',
            nextId: ' target ',
          ),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: before,
          operation: const PrefabV3DeleteOperation(prefabKey: 'missing'),
        ),
      ),
      same(document),
    );
    expect(
      apply(
        PrefabV3LifecycleCommit(
          before: before,
          operation: const PrefabV3RenameOperation(
            prefabKey: 'target',
            nextId: 'target',
          ),
        ),
      ),
      same(document),
    );
  });
}

PrefabV3StagingDocument _document(Iterable<TerrainSourceShapeDef> shapes) {
  final data = PrefabV3FileData(
    slices: const <AtlasSliceDef>[
      AtlasSliceDef(
        id: 'slice_a',
        sourceImagePath: 'assets/images/level/test.png',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
    ],
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
