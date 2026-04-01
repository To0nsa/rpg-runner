import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/prefabs/prefab_models.dart';
import 'package:runner_editor/src/prefabs/prefab_store.dart';

void main() {
  const store = PrefabStore();

  test('load returns empty v2 defaults when files are missing', () async {
    final root = Directory.systemTemp.createTempSync('prefab_store_missing_');
    try {
      final data = await store.load(root.path);
      expect(data.schemaVersion, currentPrefabSchemaVersion);
      expect(data.prefabSlices, isEmpty);
      expect(data.tileSlices, isEmpty);
      expect(data.prefabs, isEmpty);
      expect(data.platformModules, isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test(
    'save then load preserves data and writes deterministic ordering',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'prefab_store_roundtrip_',
      );
      try {
        final input = PrefabData(
          schemaVersion: 3,
          prefabSlices: const [
            AtlasSliceDef(
              id: 'z_slice',
              sourceImagePath: 'assets/images/level/props/a.png',
              x: 16,
              y: 0,
              width: 16,
              height: 16,
            ),
            AtlasSliceDef(
              id: 'a_slice',
              sourceImagePath: 'assets/images/level/props/a.png',
              x: 0,
              y: 0,
              width: 16,
              height: 16,
            ),
          ],
          tileSlices: const [
            AtlasSliceDef(
              id: 'tile_b',
              sourceImagePath: 'assets/images/level/tileset/t.png',
              x: 16,
              y: 0,
              width: 16,
              height: 16,
            ),
            AtlasSliceDef(
              id: 'tile_a',
              sourceImagePath: 'assets/images/level/tileset/t.png',
              x: 0,
              y: 0,
              width: 16,
              height: 16,
            ),
          ],
          prefabs: [
            PrefabDef(
              prefabKey: 'prefab_b',
              id: 'prefab_b',
              revision: 1,
              status: PrefabStatus.active,
              kind: PrefabKind.obstacle,
              sliceId: 'z_slice',
              anchorXPx: 4,
              anchorYPx: 5,
              colliders: [
                PrefabColliderDef(
                  offsetX: 0,
                  offsetY: 0,
                  width: 10,
                  height: 12,
                ),
              ],
              tags: ['b', 'a'],
              zIndex: 3,
              snapToGrid: false,
            ),
            PrefabDef(
              prefabKey: 'prefab_a',
              id: 'prefab_a',
              revision: 2,
              status: PrefabStatus.active,
              kind: PrefabKind.obstacle,
              sliceId: 'a_slice',
              anchorXPx: 2,
              anchorYPx: 3,
              colliders: [
                PrefabColliderDef(offsetX: 0, offsetY: 0, width: 8, height: 9),
              ],
              tags: ['z'],
              zIndex: -1,
              snapToGrid: true,
            ),
          ],
          platformModules: const [
            TileModuleDef(
              id: 'module_b',
              tileSize: 16,
              cells: [
                TileModuleCellDef(sliceId: 'tile_b', gridX: 1, gridY: 0),
                TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0),
              ],
            ),
            TileModuleDef(
              id: 'module_a',
              tileSize: 16,
              cells: [TileModuleCellDef(sliceId: 'tile_a', gridX: 0, gridY: 0)],
            ),
          ],
        );

        await store.save(root.path, data: input);
        final loaded = await store.load(root.path);

        expect(loaded.schemaVersion, 3);
        expect(loaded.prefabSlices.map((s) => s.id), ['a_slice', 'z_slice']);
        expect(loaded.tileSlices.map((s) => s.id), ['tile_a', 'tile_b']);
        expect(loaded.prefabs.map((prefab) => prefab.id), [
          'prefab_a',
          'prefab_b',
        ]);
        expect(loaded.platformModules.map((module) => module.id), [
          'module_a',
          'module_b',
        ]);
        expect(loaded.prefabs[1].tags, ['a', 'b']);
        expect(loaded.prefabs[0].zIndex, -1);
        expect(loaded.prefabs[0].snapToGrid, isTrue);
        expect(loaded.prefabs[1].zIndex, 3);
        expect(loaded.prefabs[1].snapToGrid, isFalse);
        expect(
          loaded.prefabs[0].visualSource.type,
          PrefabVisualSourceType.atlasSlice,
        );
        expect(loaded.prefabs[0].visualSource.sliceId, 'a_slice');

        final prefabJsonRaw = File(
          p.join(root.path, PrefabStore.prefabDefsPath),
        ).readAsStringSync();
        final tileJsonRaw = File(
          p.join(root.path, PrefabStore.tileDefsPath),
        ).readAsStringSync();
        expect(prefabJsonRaw, contains('"schemaVersion": 3'));
        expect(prefabJsonRaw, contains('"visualSource"'));
        expect(
          prefabJsonRaw.indexOf('"a_slice"'),
          lessThan(prefabJsonRaw.indexOf('"z_slice"')),
        );
        expect(
          tileJsonRaw.indexOf('"module_a"'),
          lessThan(tileJsonRaw.indexOf('"module_b"')),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'load migrates v1 prefab records into deterministic v2 contract',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'prefab_store_v1_to_v2_',
      );
      try {
        final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath));
        final tileFile = File(p.join(root.path, PrefabStore.tileDefsPath));
        prefabFile.parent.createSync(recursive: true);
        tileFile.parent.createSync(recursive: true);

        final prefabV1 = <String, Object?>{
          'schemaVersion': 1,
          'slices': [
            {
              'id': 'slice_a',
              'sourceImagePath': 'assets/images/level/props/a.png',
              'x': 0,
              'y': 0,
              'width': 16,
              'height': 16,
            },
            {
              'id': 'slice_b',
              'sourceImagePath': 'assets/images/level/props/a.png',
              'x': 16,
              'y': 0,
              'width': 16,
              'height': 16,
            },
          ],
          'prefabs': [
            {
              'id': 'Crate A',
              'sliceId': 'slice_a',
              'anchorXPx': 8,
              'anchorYPx': 8,
              'colliders': [
                {'offsetX': 0, 'offsetY': 0, 'width': 12, 'height': 12},
              ],
            },
            {
              'id': 'crate_a',
              'sliceId': 'slice_b',
              'anchorXPx': 8,
              'anchorYPx': 8,
              'colliders': [
                {'offsetX': 0, 'offsetY': 0, 'width': 12, 'height': 12},
              ],
            },
          ],
        };
        final tileV1 = <String, Object?>{
          'schemaVersion': 1,
          'tileSlices': [],
          'platformModules': [],
        };

        const encoder = JsonEncoder.withIndent('  ');
        prefabFile.writeAsStringSync('${encoder.convert(prefabV1)}\n');
        tileFile.writeAsStringSync('${encoder.convert(tileV1)}\n');

        final loaded = await store.load(root.path);

        expect(loaded.schemaVersion, currentPrefabSchemaVersion);
        expect(loaded.prefabs, hasLength(2));
        expect(
          loaded.prefabs.map((prefab) => prefab.prefabKey),
          containsAll(<String>['crate_a', 'crate_a_2']),
        );
        expect(loaded.prefabs.every((prefab) => prefab.revision == 1), isTrue);
        expect(
          loaded.prefabs.every(
            (prefab) => prefab.status == PrefabStatus.active,
          ),
          isTrue,
        );
        expect(
          loaded.prefabs.every((prefab) => prefab.kind == PrefabKind.obstacle),
          isTrue,
        );
        expect(
          loaded.prefabs.every(
            (prefab) =>
                prefab.visualSource.type == PrefabVisualSourceType.atlasSlice,
          ),
          isTrue,
        );
        expect(
          loaded.prefabs.map((prefab) => prefab.visualSource.sliceId),
          containsAll(<String>['slice_a', 'slice_b']),
        );

        await store.save(root.path, data: loaded);
        final persistedPrefabRaw = prefabFile.readAsStringSync();
        final persistedPrefab =
            jsonDecode(persistedPrefabRaw) as Map<String, Object?>;
        expect(persistedPrefab['schemaVersion'], currentPrefabSchemaVersion);
        expect(persistedPrefabRaw.contains('"visualSource"'), isTrue);
        expect(persistedPrefabRaw.contains('"sliceId": "slice_a"'), isTrue);
        expect(persistedPrefabRaw.contains('"prefabKey": "crate_a_2"'), isTrue);
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'loadWithReport returns deterministic migration hints for v1 data',
    () async {
      final root = Directory.systemTemp.createTempSync('prefab_store_hints_');
      try {
        final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath));
        final tileFile = File(p.join(root.path, PrefabStore.tileDefsPath));
        prefabFile.parent.createSync(recursive: true);
        tileFile.parent.createSync(recursive: true);

        const encoder = JsonEncoder.withIndent('  ');
        prefabFile.writeAsStringSync(
          '${encoder.convert(<String, Object?>{
            'schemaVersion': 1,
            'slices': <Object?>[],
            'prefabs': <Object?>[
              <String, Object?>{
                'id': 'legacy_a',
                'sliceId': 'legacy_slice',
                'anchorXPx': 0,
                'anchorYPx': 0,
                'colliders': <Object?>[
                  <String, Object?>{'offsetX': 0, 'offsetY': 0, 'width': 16, 'height': 16},
                ],
              },
            ],
          })}\n',
        );
        tileFile.writeAsStringSync(
          '${encoder.convert(<String, Object?>{'schemaVersion': 1, 'tileSlices': <Object?>[], 'platformModules': <Object?>[]})}\n',
        );

        final result = await store.loadWithReport(root.path);
        expect(result.data.schemaVersion, currentPrefabSchemaVersion);
        expect(result.migrationHints, isNotEmpty);
        expect(
          result.migrationHints.first,
          contains('Legacy prefab schema detected (v1)'),
        );
        expect(result.migrationHints.last, contains('Migration summary:'));
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test(
    'load normalizes module lifecycle defaults and save persists canonical lifecycle fields',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'prefab_store_module_lifecycle_',
      );
      try {
        final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath));
        final tileFile = File(p.join(root.path, PrefabStore.tileDefsPath));
        prefabFile.parent.createSync(recursive: true);
        tileFile.parent.createSync(recursive: true);

        const encoder = JsonEncoder.withIndent('  ');
        prefabFile.writeAsStringSync(
          '${encoder.convert(<String, Object?>{'schemaVersion': 2, 'slices': <Object?>[], 'prefabs': <Object?>[]})}\n',
        );
        tileFile.writeAsStringSync(
          '${encoder.convert(<String, Object?>{
            'schemaVersion': 2,
            'tileSlices': <Object?>[],
            'platformModules': <Object?>[
              <String, Object?>{
                'id': 'module_legacy',
                'tileSize': 16,
                'cells': <Object?>[
                  <String, Object?>{
                    'sliceId': 'tile_a',
                    'gridX': 0,
                    'gridY': 0,
                  },
                ],
              },
              <String, Object?>{
                'id': 'module_bad',
                'revision': 0,
                'status': 'unknown',
                'tileSize': 16,
                'cells': <Object?>[
                  <String, Object?>{
                    'sliceId': 'tile_a',
                    'gridX': 1,
                    'gridY': 0,
                  },
                ],
              },
              <String, Object?>{
                'id': 'module_deprecated',
                'revision': 3,
                'status': 'deprecated',
                'tileSize': 16,
                'cells': <Object?>[
                  <String, Object?>{
                    'sliceId': 'tile_a',
                    'gridX': 2,
                    'gridY': 0,
                  },
                ],
              },
            ],
          })}\n',
        );

        final loaded = await store.load(root.path);
        final legacy = loaded.platformModules.firstWhere(
          (module) => module.id == 'module_legacy',
        );
        final bad = loaded.platformModules.firstWhere(
          (module) => module.id == 'module_bad',
        );
        final deprecated = loaded.platformModules.firstWhere(
          (module) => module.id == 'module_deprecated',
        );

        expect(legacy.revision, 1);
        expect(legacy.status, TileModuleStatus.active);
        expect(bad.revision, 1);
        expect(bad.status, TileModuleStatus.active);
        expect(deprecated.revision, 3);
        expect(deprecated.status, TileModuleStatus.deprecated);

        await store.save(root.path, data: loaded);
        final persisted =
            jsonDecode(tileFile.readAsStringSync()) as Map<String, Object?>;
        final modules =
            persisted['platformModules'] as List<Object?>? ?? const <Object?>[];
        expect(modules, isNotEmpty);
        for (final raw in modules) {
          final module = raw as Map<Object?, Object?>;
          expect(module.containsKey('revision'), isTrue);
          expect(module.containsKey('status'), isTrue);
          expect(module['status'], isNot('unknown'));
        }
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );

  test('load throws a FormatException for malformed JSON', () async {
    final root = Directory.systemTemp.createTempSync('prefab_store_bad_json_');
    try {
      final prefabFile = File(p.join(root.path, PrefabStore.prefabDefsPath));
      prefabFile.parent.createSync(recursive: true);
      prefabFile.writeAsStringSync('{"schemaVersion": 2,');

      expect(
        () => store.load(root.path),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Malformed JSON in'),
          ),
        ),
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('save leaves no staged temp/backup files behind', () async {
    final root = Directory.systemTemp.createTempSync('prefab_store_atomic_');
    try {
      await store.save(root.path, data: const PrefabData());

      final levelDir = Directory(
        p.join(root.path, 'assets', 'authoring', 'level'),
      );
      final staged = levelDir
          .listSync(followLinks: false)
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .where(
            (name) =>
                name.contains('.tmp') ||
                name.contains('.bak') ||
                name.startsWith('.prefab_defs.json.') ||
                name.startsWith('.tile_defs.json.'),
          )
          .toList(growable: false);
      expect(staged, isEmpty);
    } finally {
      root.deleteSync(recursive: true);
    }
  });
}
