import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_polygon_metadata_dialog.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  testWidgets('retains unregistered metadata values until explicitly changed', (
    tester,
  ) async {
    TerrainPolygonMetadataEdit? acceptedEdit;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              acceptedEdit = await showTerrainPolygonMetadataDialog(
                context,
                keyPrefix: 'test_polygon',
                workspaceRootPath: Directory.systemTemp.path,
                shape: TerrainSourceShapeDef(
                  shapeId: 'ground_001',
                  surfaceKind: 'legacy_surface',
                  materialKey: 'legacy_material',
                  vertices: const <TerrainSourceVertexDef>[
                    TerrainSourceVertexDef(
                      xHalfPixels: 0,
                      yHalfPixels: 0,
                    ),
                    TerrainSourceVertexDef(
                      xHalfPixels: 20,
                      yHalfPixels: 0,
                    ),
                    TerrainSourceVertexDef(
                      xHalfPixels: 20,
                      yHalfPixels: 20,
                    ),
                  ],
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('legacy_surface'), findsOneWidget);
    expect(find.text('legacy_material'), findsOneWidget);
    expect(
      find.text('No preview assets are registered for legacy_material.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('test_polygon_metadata_apply')),
    );
    await tester.pumpAndSettle();

    expect(acceptedEdit?.surfaceKind, 'legacy_surface');
    expect(acceptedEdit?.materialKey, 'legacy_material');
  });
}
