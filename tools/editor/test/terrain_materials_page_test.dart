import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/terrainMaterials/terrain_materials_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TerrainMaterialsPage(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Grass / Dirt'), findsWidgets);
    expect(find.textContaining('grass_dirt · rev 1'), findsOneWidget);
    expect(find.text('Top / slope · configured'), findsOneWidget);
    expect(find.text('Left wall · fill only'), findsOneWidget);
    expect(find.text('Cliff caps · configured'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('terrain_material_edit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
