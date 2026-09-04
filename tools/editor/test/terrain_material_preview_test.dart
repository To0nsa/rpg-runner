import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/shared/terrain_material_preview.dart';
import 'package:terrain_materials/terrain_materials.dart';

void main() {
  testWidgets('composed preview refreshes every configured edge orientation', (
    tester,
  ) async {
    final workspaceRoot = p.normalize(
      p.absolute(p.join(Directory.current.path, '..', '..')),
    );
    const assetPath = 'assets/images/level/atlases/tiny_swords/ground.png';

    final topOnly = _material(assetPath: assetPath);
    await tester.pumpWidget(_preview(workspaceRoot, topOnly));
    await tester.pumpAndSettle();

    expect(_composedRole('top_base'), findsOneWidget);
    expect(_composedRole('right_wall_base'), findsNothing);
    expect(_composedRole('underside_base'), findsNothing);
    expect(_composedRole('left_wall_base'), findsNothing);

    final profile = _profile(assetPath);
    final cap = TerrainMaterialCap(
      region: _region(assetPath),
      anchorX: 0,
      anchorY: 0,
    );
    final configured = topOnly.copyWith(
      revision: 2,
      leftWall: profile,
      rightWall: profile,
      underside: profile,
      undersideStartCap: cap,
      undersideEndCap: cap,
    );
    await tester.pumpWidget(_preview(workspaceRoot, configured));
    await tester.pumpAndSettle();

    expect(_composedRole('top_base'), findsOneWidget);
    expect(_composedRole('right_wall_base'), findsOneWidget);
    expect(_composedRole('underside_base'), findsOneWidget);
    expect(_composedRole('left_wall_base'), findsOneWidget);
    expect(_composedRole('underside_start_cap'), findsOneWidget);
    expect(_composedRole('underside_end_cap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _preview(String workspaceRootPath, TerrainMaterialDefinition material) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: TerrainMaterialPreview(
              key: const ValueKey<String>('preview'),
              keyPrefix: 'test',
              workspaceRootPath: workspaceRootPath,
              material: material,
            ),
          ),
        ),
      ),
    );

Finder _composedRole(String role) =>
    find.byKey(ValueKey<String>('test_material_preview_composed_$role'));

TerrainMaterialDefinition _material({required String assetPath}) {
  final region = _region(assetPath);
  return TerrainMaterialDefinition(
    key: 'test_material',
    displayName: 'Test material',
    revision: 1,
    fill: region,
    top: _profile(assetPath),
    topStartCap: TerrainMaterialCap(region: region, anchorX: 0, anchorY: 0),
    topEndCap: TerrainMaterialCap(region: region, anchorX: 1, anchorY: 0),
  );
}

TerrainMaterialEdgeProfile _profile(String assetPath) =>
    TerrainMaterialEdgeProfile(
      base: TerrainMaterialEdgeLayer(region: _region(assetPath), anchorY: 0),
    );

TerrainMaterialImageRegion _region(String assetPath) =>
    TerrainMaterialImageRegion(
      assetPath: assetPath,
      x: 0,
      y: 0,
      width: 1,
      height: 1,
    );
