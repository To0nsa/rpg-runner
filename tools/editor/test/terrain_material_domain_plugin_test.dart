import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_models.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_plugin.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';
import 'package:terrain_materials/terrain_materials.dart';

void main() {
  test(
    'catalog CRUD preserves ordering and protects referenced keys',
    () async {
      final fixture = await _TerrainMaterialFixture.create();
      addTearDown(fixture.dispose);
      final plugin = TerrainMaterialDomainPlugin();
      final workspace = EditorWorkspace(rootPath: fixture.root.path);
      final loaded =
          await plugin.loadFromRepo(workspace) as TerrainMaterialDocument;

      expect(loaded.materials.single.key, 'grass_dirt');
      expect(loaded.referencedMaterialKeys, contains('grass_dirt'));
      expect(plugin.validate(loaded), isEmpty);

      final protectedDelete = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'delete_material',
          payload: const <String, Object?>{'key': 'grass_dirt'},
        ),
      );
      expect(protectedDelete, same(loaded));

      final protectedRename = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'upsert_material',
          payload: <String, Object?>{
            'previousKey': 'grass_dirt',
            'material': fixture.material.copyWith(key: 'renamed'),
          },
        ),
      );
      expect(protectedRename, same(loaded));

      final stone = fixture.material.copyWith(
        key: 'stone',
        displayName: 'Stone',
      );
      final added = plugin.applyEdit(
        loaded,
        AuthoringCommand(
          kind: 'upsert_material',
          payload: <String, Object?>{'previousKey': '', 'material': stone},
        ),
      ) as TerrainMaterialDocument;
      expect(added.materials.map((material) => material.key), <String>[
        'grass_dirt',
        'stone',
      ]);
      expect(
        plugin.describePendingChanges(workspace, document: added).hasChanges,
        isTrue,
      );

      final removed = plugin.applyEdit(
        added,
        AuthoringCommand(
          kind: 'delete_material',
          payload: const <String, Object?>{'key': 'stone'},
        ),
      ) as TerrainMaterialDocument;
      expect(removed.materials.single.key, 'grass_dirt');
    },
  );

  test(
    'missing material images and polygon keys are blocking issues',
    () async {
      final fixture = await _TerrainMaterialFixture.create();
      addTearDown(fixture.dispose);
      File(p.join(fixture.root.path, fixture.material.fill.assetPath))
          .deleteSync();
      File(
        p.join(
          fixture.root.path,
          'assets',
          'authoring',
          'level',
          'prefab_defs.json',
        ),
      ).writeAsStringSync('{"materialKey":"missing_material"}');
      final plugin = TerrainMaterialDomainPlugin();
      final document = await plugin.loadFromRepo(
        EditorWorkspace(rootPath: fixture.root.path),
      );

      final codes = plugin
          .validate(document)
          .map((issue) => issue.code)
          .toSet();
      expect(codes, contains('terrain_material_asset_missing'));
      expect(codes, contains('referenced_material_missing'));
    },
  );
}

final class _TerrainMaterialFixture {
  _TerrainMaterialFixture({required this.root, required this.material});

  final Directory root;
  final TerrainMaterialDefinition material;

  static Future<_TerrainMaterialFixture> create() async {
    final root = await Directory.systemTemp.createTemp('terrain_materials_');
    const material = TerrainMaterialDefinition(
      key: 'grass_dirt',
      displayName: 'Grass / Dirt',
      revision: 1,
      fill: TerrainMaterialImageRegion(
        assetPath: 'assets/images/level/atlases/tiny_swords/ground.png',
        x: 32,
        y: 32,
        width: 32,
        height: 32,
      ),
      top: TerrainMaterialEdgeProfile(
        base: TerrainMaterialEdgeLayer(
          region: TerrainMaterialImageRegion(
            assetPath: 'assets/images/level/atlases/tiny_swords/ground.png',
            x: 32,
            y: 0,
            width: 32,
            height: 32,
          ),
          anchorY: 12,
        ),
      ),
      topStartCap: TerrainMaterialCap(
        region: TerrainMaterialImageRegion(
          assetPath: 'assets/images/level/atlases/tiny_swords/ground.png',
          x: 0,
          y: 0,
          width: 32,
          height: 32,
        ),
        anchorX: 0,
        anchorY: 12,
      ),
      topEndCap: TerrainMaterialCap(
        region: TerrainMaterialImageRegion(
          assetPath: 'assets/images/level/atlases/tiny_swords/ground.png',
          x: 64,
          y: 0,
          width: 32,
          height: 32,
        ),
        anchorX: 32,
        anchorY: 12,
      ),
    );
    final catalogFile = File(
      p.join(
        root.path,
        'assets',
        'authoring',
        'level',
        'terrain_material_defs.json',
      ),
    )..parent.createSync(recursive: true);
    catalogFile.writeAsStringSync(
      TerrainMaterialCatalog(materials: <TerrainMaterialDefinition>[material])
          .toCanonicalJson(),
    );
    final prefabFile = File(
      p.join(root.path, 'assets', 'authoring', 'level', 'prefab_defs.json'),
    );
    prefabFile.writeAsStringSync('{"materialKey":"grass_dirt"}');
    for (final assetPath in terrainMaterialAssetPaths(material)) {
      final file = File(p.join(root.path, assetPath));
      file.parent.createSync(recursive: true);
      File(
        p.normalize(
          p.absolute(p.join(Directory.current.path, '..', '..', assetPath)),
        ),
      ).copySync(file.path);
    }
    return _TerrainMaterialFixture(root: root, material: material);
  }

  void dispose() => root.deleteSync(recursive: true);
}
