import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_store.dart';
import 'package:runner_editor/src/workspace/editor_workspace.dart';

void main() {
  test('load/save round-trips parallax data deterministically', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = ParallaxStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );

      expect(loaded.availableLevelIds, <String>['field', 'forest']);
      expect(loaded.activeLevelId, 'field');
      expect(resolveActiveThemeId(loaded), 'field');
      expect(loaded.themes, hasLength(2));

      final fieldTheme = loaded.themes.firstWhere((theme) => theme.themeId == 'field');
      final editedTheme = fieldTheme.copyWith(
        groundMaterialAssetPath: 'assets/images/parallax/field/ground_alt.png',
        layers: <ParallaxLayerDef>[
          const ParallaxLayerDef(
            layerKey: 'field_fg_20',
            assetPath: 'assets/images/parallax/field/fg_20.png',
            group: parallaxGroupForeground,
            parallaxFactor: 1.2,
            zOrder: 20,
            opacity: 1.0,
            yOffset: 0.0,
          ),
          ...fieldTheme.layers.reversed,
        ],
      );
      final edited = loaded.copyWith(
        themes: <ParallaxThemeDef>[
          loaded.themes.firstWhere((theme) => theme.themeId == 'forest'),
          editedTheme,
        ],
      );
      final savePlan = store.buildSavePlan(workspace, document: edited);

      expect(savePlan.hasChanges, isTrue);
      await store.save(workspace, document: edited, savePlan: savePlan);

      final savedRaw = File(
        p.join(fixtureRoot.path, ParallaxStore.defsPath),
      ).readAsStringSync();
      final savedJson = jsonDecode(savedRaw) as Map<String, Object?>;
      expect(savedJson['schemaVersion'], parallaxSchemaVersion);
      final savedThemes = savedJson['themes'] as List<Object?>;
      final savedFieldTheme = savedThemes
          .cast<Map<String, Object?>>()
          .firstWhere((theme) => theme['themeId'] == 'field');
      expect(
        savedFieldTheme['groundMaterialAssetPath'],
        'assets/images/parallax/field/ground_alt.png',
      );
      final savedLayers =
          savedFieldTheme['layers'] as List<Object?>;
      expect(
        (savedLayers.first as Map<String, Object?>)['layerKey'],
        'field_bg_10',
      );
      expect(
        (savedLayers.last as Map<String, Object?>)['layerKey'],
        'field_fg_20',
      );

      final reloaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );
      final reloadedFieldTheme = reloaded.themes.firstWhere(
        (theme) => theme.themeId == 'field',
      );
      expect(reloadedFieldTheme.layers.last.layerKey, 'field_fg_20');
      expect(
        reloadedFieldTheme.groundMaterialAssetPath,
        'assets/images/parallax/field/ground_alt.png',
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });

  test('save fails when source drift is detected', () async {
    final fixtureRoot = await _createFixtureWorkspace();
    try {
      final workspace = EditorWorkspace(rootPath: fixtureRoot.path);
      const store = ParallaxStore();
      final loaded = await store.load(
        workspace,
        preferredActiveLevelId: 'field',
      );
      final fieldTheme = loaded.themes.firstWhere((theme) => theme.themeId == 'field');
      final edited = loaded.copyWith(
        themes: <ParallaxThemeDef>[
          fieldTheme.copyWith(revision: fieldTheme.revision + 1),
          loaded.themes.firstWhere((theme) => theme.themeId == 'forest'),
        ],
      );
      final savePlan = store.buildSavePlan(workspace, document: edited);

      File(
        p.join(fixtureRoot.path, ParallaxStore.defsPath),
      ).writeAsStringSync('{}\n');

      await expectLater(
        store.save(workspace, document: edited, savePlan: savePlan),
        throwsA(isA<StateError>()),
      );
    } finally {
      fixtureRoot.deleteSync(recursive: true);
    }
  });
}

Future<Directory> _createFixtureWorkspace() async {
  final root = await Directory.systemTemp.createTemp('parallax_store_fixture_');
  _writeFile(
    root.path,
    'assets/authoring/level/level_defs.json',
    '''
{
  "levelIds": ["field", "forest"]
}
''',
  );
  _writeFile(
    root.path,
    'packages/runner_core/lib/levels/level_registry.dart',
    '''
class LevelRegistry {
  static Object byId(Object id) {
    switch (id) {
      case LevelId.field:
        return LevelDefinition(themeId: 'field');
      case LevelId.forest:
        return LevelDefinition(themeId: 'forest');
    }
  }
}
''',
  );
  _writeFile(
    root.path,
    'assets/authoring/level/parallax_defs.json',
    '''
{
  "schemaVersion": 1,
  "themes": [
    {
      "themeId": "field",
      "revision": 1,
      "groundMaterialAssetPath": "assets/images/parallax/field/ground.png",
      "layers": [
        {
          "layerKey": "field_bg_10",
          "assetPath": "assets/images/parallax/field/bg_10.png",
          "group": "background",
          "parallaxFactor": 0.2,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        },
        {
          "layerKey": "field_fg_10",
          "assetPath": "assets/images/parallax/field/fg_10.png",
          "group": "foreground",
          "parallaxFactor": 1,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        }
      ]
    },
    {
      "themeId": "forest",
      "revision": 1,
      "groundMaterialAssetPath": "assets/images/parallax/forest/ground.png",
      "layers": [
        {
          "layerKey": "forest_bg_10",
          "assetPath": "assets/images/parallax/forest/bg_10.png",
          "group": "background",
          "parallaxFactor": 0.3,
          "zOrder": 10,
          "opacity": 1,
          "yOffset": 0
        }
      ]
    }
  ]
}
''',
  );
  for (final assetPath in <String>[
    'assets/images/parallax/field/ground.png',
    'assets/images/parallax/field/ground_alt.png',
    'assets/images/parallax/field/bg_10.png',
    'assets/images/parallax/field/fg_10.png',
    'assets/images/parallax/field/fg_20.png',
    'assets/images/parallax/forest/ground.png',
    'assets/images/parallax/forest/bg_10.png',
  ]) {
    _writeBinaryFile(root.path, assetPath);
  }
  return root;
}

void _writeFile(String rootPath, String relativePath, String content) {
  final absolutePath = p.join(rootPath, relativePath);
  final file = File(absolutePath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content.trimLeft());
}

void _writeBinaryFile(String rootPath, String relativePath) {
  final absolutePath = p.join(rootPath, relativePath);
  final file = File(absolutePath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(const <int>[0]);
}
