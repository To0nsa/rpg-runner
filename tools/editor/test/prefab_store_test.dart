import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/prefabs/prefab_models.dart';
import 'package:runner_editor/src/prefabs/prefab_store.dart';

void main() {
  const store = PrefabStore();

  test('load returns empty default data when files are missing', () async {
    final root = Directory.systemTemp.createTempSync('prefab_store_missing_');
    try {
      final data = await store.load(root.path);
      expect(data.schemaVersion, 1);
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
          prefabs: const [
            PrefabDef(
              id: 'prefab_b',
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
              id: 'prefab_a',
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
        expect(loaded.prefabs.map((p) => p.id), ['prefab_a', 'prefab_b']);
        expect(loaded.platformModules.map((m) => m.id), [
          'module_a',
          'module_b',
        ]);
        expect(loaded.prefabs[1].tags, ['a', 'b']);
        expect(loaded.prefabs[0].zIndex, -1);
        expect(loaded.prefabs[0].snapToGrid, isTrue);
        expect(loaded.prefabs[1].zIndex, 3);
        expect(loaded.prefabs[1].snapToGrid, isFalse);

        final prefabJson = File(
          p.join(root.path, PrefabStore.prefabDefsPath),
        ).readAsStringSync();
        final tileJson = File(
          p.join(root.path, PrefabStore.tileDefsPath),
        ).readAsStringSync();
        expect(prefabJson, contains('"schemaVersion": 3'));
        expect(
          prefabJson.indexOf('"a_slice"'),
          lessThan(prefabJson.indexOf('"z_slice"')),
        );
        expect(
          tileJson.indexOf('"module_a"'),
          lessThan(tileJson.indexOf('"module_b"')),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );
}
