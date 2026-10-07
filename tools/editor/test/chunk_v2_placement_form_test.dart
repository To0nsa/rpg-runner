import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/chunkCreator/v2/chunk_v2_composition_forms.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/terrain_authoring/terrain_source_models.dart';

void main() {
  testWidgets('unsupported saved rotation can be explicitly cleared', (
    tester,
  ) async {
    PlacedPrefabDef? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChunkV2PlacementForm(
              prefab: _halfPixelSupportPrefab(),
              placement: const PlacedPrefabDef(
                prefabId: 'crate',
                prefabKey: 'crate',
                x: 10,
                y: 20,
                scale: 2,
                rotationDegrees: 45,
              ),
              submitKey: 'submit',
              submitLabel: 'Apply',
              onSubmit: (value) => submitted = value,
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('chunk_v2_placement_rotation_field')),
      findsNothing,
    );
    final reset = find.byKey(
      const ValueKey<String>('chunk_v2_placement_rotation_reset'),
    );
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pump();
    final submit = find.byKey(const ValueKey<String>('submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    expect(submitted!.rotationDegrees, 0);
  });

  testWidgets(
    'decoration rotation wraps finite input, blocks invalid input and clears for collision owners',
    (tester) async {
      final decoration = _halfPixelSupportPrefab().copyWith(
        kind: PrefabKind.decoration,
        collisionShapes: [],
      );
      PlacedPrefabDef? submitted;
      Future<void> mount(PrefabV3Def prefab) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChunkV2PlacementForm(
                prefab: prefab,
                placement: const PlacedPrefabDef(
                  prefabId: 'crate',
                  prefabKey: 'crate',
                  x: 10,
                  y: 20,
                ),
                submitKey: 'submit',
                submitLabel: 'Apply',
                onSubmit: (p) => submitted = p,
              ),
            ),
          ),
        ),
      );
      await mount(decoration);
      final field = find.byKey(
        const ValueKey<String>('chunk_v2_placement_rotation_field'),
      );
      final submit = find.byKey(const ValueKey<String>('submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.enterText(field, '-90.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        tester
            .widget<Slider>(
              find.byKey(
                const ValueKey<String>('chunk_v2_placement_rotation_slider'),
              ),
            )
            .value,
        269.5,
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      expect(submitted!.rotationDegrees, 269.5);
      expect((submitted!.x, submitted!.y), (10, 20));
      submitted = null;
      await tester.ensureVisible(field);
      await tester.enterText(field, 'NaN');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      expect(submitted, isNull);
      expect(find.text('Enter a finite angle.'), findsWidgets);
      await mount(_halfPixelSupportPrefab().copyWith(prefabKey: 'other'));
      expect(field, findsNothing);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      expect(submitted!.rotationDegrees, 0);
    },
  );

  testWidgets('new placement offers only whole-pixel contact scales', (
    tester,
  ) async {
    PlacedPrefabDef? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChunkV2PlacementForm(
              prefab: _halfPixelSupportPrefab(),
              submitKey: 'submit',
              submitLabel: 'Add',
              onSubmit: (candidate) => submitted = candidate,
            ),
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('chunk_v2_placement_scale_field')),
    );
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey<String>('chunk_v2_placement_scale_slider')),
    );
    expect(field.controller!.text, '2.0');
    expect(slider.value, 0);
    expect(slider.onChanged, isNull);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey<String>('chunk_v2_placement_snap_field')),
          )
          .value,
      isFalse,
    );
    expect(find.textContaining('exact-contact'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('submit')));
    expect(submitted?.scale, 2.0);
    expect(submitted?.snapToGrid, isFalse);
  });

  testWidgets(
    'saved incompatible scale is retained as a discrete slider stop',
    (tester) async {
      PlacedPrefabDef? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChunkV2PlacementForm(
                prefab: _halfPixelSupportPrefab(),
                placement: const PlacedPrefabDef(
                  prefabId: 'crate',
                  prefabKey: 'crate',
                  x: 10,
                  y: 20,
                  snapToGrid: true,
                  scale: 1,
                ),
                submitKey: 'submit',
                submitLabel: 'Apply',
                onSubmit: (candidate) => submitted = candidate,
              ),
            ),
          ),
        ),
      );

      var field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('chunk_v2_placement_scale_field')),
      );
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey<String>('chunk_v2_placement_scale_slider')),
      );
      expect(field.controller!.text, '1.0');
      expect(slider.value, 0);
      expect(slider.divisions, 1);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(
                const ValueKey<String>('chunk_v2_placement_snap_field'),
              ),
            )
            .value,
        isTrue,
      );
      expect(find.textContaining('saved scale is retained'), findsNothing);

      slider.onChanged!(1);
      await tester.pump();
      field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('chunk_v2_placement_scale_field')),
      );
      expect(field.controller!.text, '2.0');

      await tester.tap(find.byKey(const ValueKey<String>('submit')));
      expect(submitted?.scale, 2.0);
    },
  );
}

PrefabV3Def _halfPixelSupportPrefab() => PrefabV3Def(
  prefabKey: 'crate',
  id: 'crate',
  revision: 1,
  status: PrefabStatus.active,
  kind: PrefabKind.obstacle,
  visualSource: const PrefabVisualSource.atlasSlice('crate'),
  anchorXPx: 10,
  anchorYPx: 20,
  collisionShapes: <TerrainSourceShapeDef>[
    TerrainSourceShapeDef(
      shapeId: 'body',
      vertices: const <TerrainSourceVertexDef>[
        TerrainSourceVertexDef(xHalfPixels: -20, yHalfPixels: -39),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: -39),
        TerrainSourceVertexDef(xHalfPixels: 20, yHalfPixels: 1),
        TerrainSourceVertexDef(xHalfPixels: -20, yHalfPixels: 1),
      ],
    ),
  ],
  tags: const <String>[],
);
