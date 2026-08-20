import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/terrainMaterials/terrain_materials_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_models.dart';
import 'package:runner_editor/src/terrain_materials/terrain_material_domain_plugin.dart';

void main() {
  testWidgets('material route shows composed assets and explicit coverage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    final plugin = TerrainMaterialDomainPlugin();
    final controller = EditorSessionController(
      pluginRegistry: AuthoringPluginRegistry(
        plugins: <AuthoringDomainPlugin>[plugin],
      ),
      initialPluginId: TerrainMaterialDomainPlugin.pluginId,
      initialWorkspacePath: workspaceRoot,
    );
    await tester.runAsync(controller.loadWorkspace);
    final scene = controller.scene! as TerrainMaterialScene;
    final loadedMaterial = scene.materials.singleWhere(
      (material) => material.key == 'grass_dirt',
    );
    final initialRevision = loadedMaterial.revision;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerrainMaterialsPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Grass / Dirt'), findsWidgets);
    expect(
      find.textContaining('grass_dirt · rev $initialRevision'),
      findsOneWidget,
    );
    expect(find.text('Top / slope · configured'), findsOneWidget);
    expect(
      find.text(
        'Left wall · '
        '${loadedMaterial.leftWall == null ? 'fill only' : 'configured'}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Cliff caps · '
        '${loadedMaterial.topStartCap != null && loadedMaterial.topEndCap != null ? 'configured' : 'fill only'}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Bottom corners · '
        '${loadedMaterial.undersideStartCap != null && loadedMaterial.undersideEndCap != null ? 'configured' : 'fill only'}',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('terrain_material_edit')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('terrain_material_edit')),
    );
    await tester.pumpAndSettle();
    final save = find.byKey(
      const ValueKey<String>('terrain_material_dialog_apply'),
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      controller.pendingChanges.hasChanges,
      isFalse,
      reason: controller.pendingChanges.fileDiffs
          .map((diff) => diff.unifiedDiff)
          .join('\n'),
    );
    expect(
      find.textContaining('grass_dirt · rev $initialRevision'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('terrain_material_edit')),
    );
    await tester.pumpAndSettle();
    final fillField = find.byKey(
      const ValueKey<String>('terrain_material_fill_region'),
    );
    final changeRegion = find.descendant(
      of: fillField,
      matching: find.widgetWithText(OutlinedButton, 'Change region'),
    );
    await tester.ensureVisible(changeRegion);
    await tester.tap(changeRegion);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('terrain_atlas_region_picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('terrain_atlas_auto_slice_toggle')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('terrain_atlas_auto_slice_toggle')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('terrain_atlas_region_x_field')),
      '33',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('terrain_atlas_region_y_field')),
      '33',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('terrain_atlas_region_w_field')),
      '31',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('terrain_atlas_region_h_field')),
      '31',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('terrain_atlas_region_assign')),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('grass_dirt · rev ${initialRevision + 1}'),
      findsOneWidget,
    );
    expect(controller.pendingChanges.hasChanges, isTrue);
    expect(tester.takeException(), isNull);
  });
}
