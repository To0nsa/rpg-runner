import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrain_materials/terrain_materials.dart';
import 'package:runner_editor/src/app/pages/entities/entities_editor_page.dart';
import 'package:runner_editor/src/app/pages/home/editor_home_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_page.dart';
import 'package:runner_editor/src/app/pages/levelCreator/level_creator_navigation.dart';
import 'package:runner_editor/src/app/pages/parallaxEditor/parallax_editor_page.dart';
import 'package:runner_editor/src/app/pages/shared/editor_page_navigation_state.dart';
import 'package:runner_editor/src/app/pages/terrainMaterials/terrain_materials_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/entities/entity_domain_models.dart';
import 'package:runner_editor/src/entities/entity_domain_plugin.dart';
import 'package:runner_editor/src/levels/level_domain_models.dart';
import 'package:runner_editor/src/levels/level_domain_plugin.dart';
import 'package:runner_editor/src/parallax/parallax_domain_models.dart';
import 'package:runner_editor/src/parallax/parallax_domain_plugin.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_models.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_plugin.dart';

import 'test_support/chunk_level_fixture.dart';
import 'test_support/entity_test_support.dart';

void main() {
  testWidgets(
    'Entities, Materials, Parallax and Levels resume their last locations',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final workspace = (await tester.runAsync(createChunkLevelFixture))!;
      writeEntityColliderFixture(workspace.rootPath);
      void write(String path, String contents) {
        final file = File(workspace.resolve(path));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(contents);
      }

      final materials = decodeTerrainMaterialCatalog(
        File(workspace.resolve(terrainMaterialDefsSourcePath))
            .readAsStringSync(),
      ).catalog!;
      write(
        terrainMaterialDefsSourcePath,
        TerrainMaterialCatalog(
          materials: [
            ...materials.materials,
            materials.materials.first.copyWith(
              key: 'stone',
              displayName: 'Stone',
            ),
          ],
        ).toCanonicalJson(),
      );
      write(
        levelDefsSourcePath,
        renderCanonicalLevelDefsJson([
          standardChunkFixtureLevel,
          standardChunkFixtureLevel.copyWith(
            levelId: 'summit',
            displayName: 'Summit',
            visualThemeId: 'summit',
            enumOrdinal: 2,
          ),
        ]),
      );
      const asset = 'assets/images/parallax/test/layer_01.png';
      final image = File(workspace.resolve(asset));
      image.parent.createSync(recursive: true);
      image.writeAsBytesSync(
        File(workspace.resolve(materials.materials.first.fill.assetPath))
            .readAsBytesSync(),
      );
      write(
        parallaxDefsSourcePath,
        renderCanonicalParallaxDefsJson([
          for (final id in ['forest', 'summit'])
            ParallaxThemeDef(
              parallaxThemeId: id,
              revision: 1,
              layers: [
                for (final i in [1, 2])
                  ParallaxLayerDef(
                    layerKey: '${id}_$i',
                    assetPath: asset,
                    group: parallaxGroupBackground,
                    parallaxFactor: 0.5,
                    zOrder: i,
                    opacity: 1,
                    yOffset: 0,
                  ),
              ],
            ),
        ]),
      );
      final controller = EditorSessionController(
        pluginRegistry: AuthoringPluginRegistry(
          plugins: [
            EntityDomainPlugin(),
            TerrainMaterialDomainPlugin(),
            ParallaxDomainPlugin(),
            LevelDomainPlugin(),
          ],
        ),
        initialPluginId: EntityDomainPlugin.pluginId,
        initialWorkspacePath: workspace.rootPath,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadWorkspace);
      await tester.pumpWidget(
        MaterialApp(home: EditorHomePage(controller: controller)),
      );
      await _drain(tester);
      final entry = (controller.scene! as EntityScene).entries.last;
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Search Entries',
        ),
        entry.id,
      );
      await _drain(tester);
      final entity = _location<EntitiesEditorLocation>(
        tester,
        EntitiesEditorPage,
      );
      expect(entity.entryId, entry.id);

      await _route(tester, 'TERRAIN MATERIALS');
      await tester.tap(
        find.byKey(const ValueKey('terrain_material_row_stone')),
      );
      await _drain(tester);
      await _route(tester, 'PARALLAX');
      controller.applyPresentationCommand(
        AuthoringCommand(
          kind: 'set_active_level',
          payload: {'levelId': 'summit'},
        ),
      );
      await _drain(tester);
      await tester.tap(
        find.byKey(const ValueKey('parallax_layer_entry_summit_2')),
      );
      await _drain(tester);
      await _route(tester, 'LEVEL CREATOR');
      await tester.tap(find.byKey(const ValueKey('level_library_summit')));
      await _drain(tester);
      await tester.tap(find.text('Appearance').first);
      await _drain(tester);

      await _route(tester, 'ENTITIES');
      final resumedEntity = _location<EntitiesEditorLocation>(
        tester,
        EntitiesEditorPage,
      );
      expect(resumedEntity.entryId, entry.id);
      expect(resumedEntity.search, entity.search);
      await _route(tester, 'TERRAIN MATERIALS');
      expect(
        _location<TerrainMaterialsLocation>(
          tester,
          TerrainMaterialsPage,
        ).materialKey,
        'stone',
      );
      await _route(tester, 'PARALLAX');
      final parallax = _location<ParallaxEditorLocation>(
        tester,
        ParallaxEditorPage,
      );
      expect(parallax.levelId, 'summit');
      expect(parallax.layerKey, 'summit_2');
      await _route(tester, 'LEVEL CREATOR');
      final level = _location<LevelCreatorReturnContext>(
        tester,
        LevelCreatorPage,
      );
      expect(level.levelId, 'summit');
      expect(level.tab, LevelCreatorTab.appearance);
      expect(controller.pendingChanges.hasChanges, isFalse);
      expect(controller.sourceWriteCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _drain(tester);
    },
  );
}

T _location<T extends EditorPageLocation>(WidgetTester tester, Type page) =>
    (tester.state(
          find.byType(page),
        ) as EditorPageNavigationState).navigationLocation!
        as T;

Future<void> _route(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await _drain(tester);
}

Future<void> _drain(WidgetTester tester) async {
  // Repository reads and dependent previews complete outside fake frame time.
  for (var i = 0; i < 25; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}
