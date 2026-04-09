import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/prefabCreator/prefab_creator_page.dart';
import 'package:runner_editor/src/domain/authoring_plugin_registry.dart';
import 'package:runner_editor/src/domain/authoring_types.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_models.dart';
import 'package:runner_editor/src/prefabs/domain/prefab_domain_plugin.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';
import 'package:runner_editor/src/session/editor_session_controller.dart';

void main() {
  testWidgets(
    'atlas slicer filters slices by source and preserves prefab or tile selections',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createAtlasSlicerFixture();

      await _pumpPrefabCreatorPage(
        tester,
        workspacePath: fixtureRoot.path,
        openObstacleTab: false,
      );

      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_crate_slice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_barrel_slice')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('atlas_slice_row_crate_slice')),
      );
      await tester.pumpAndSettle();

      await _selectDropdownItem(
        tester,
        label: 'Atlas/Tileset Source',
        itemText: 'assets/images/level/props/props_b.png',
      );

      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_barrel_slice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_crate_slice')),
        findsNothing,
      );
      expect(
        find.text('The current selection belongs to another source.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('atlas_slice_row_barrel_slice')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected Prefab Slice: barrel_slice'), findsOneWidget);

      await tester.tap(find.text('Obstacle Prefabs').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Slice: barrel_slice'), findsOneWidget);

      await tester.tap(find.text('Atlas Slicer').first);
      await tester.pumpAndSettle();

      await _selectDropdownItem(
        tester,
        label: 'Slice Kind',
        itemText: 'Tile Slice',
      );
      await _selectDropdownItem(
        tester,
        label: 'Atlas/Tileset Source',
        itemText: 'assets/images/level/tileset/tiles_b.png',
      );

      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_wall_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('atlas_slice_row_ground_tile')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('atlas_slice_row_wall_tile')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Platform Modules').first);
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'wall_tile (16x16)'),
      );
      expect(chip.selected, isTrue);
    },
  );

  testWidgets('tabs split obstacle, module, and platform prefab authoring', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('obstacle_prefab_inspector_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('obstacle_prefab_scene_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('obstacle_prefab_display_card')),
      findsOneWidget,
    );

    await tester.tap(find.text('Platform Modules').first);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Module Controls'), findsOneWidget);
    expect(find.text('Platform Prefab Output'), findsNothing);
    expect(_dropdownByLabel('Atlas Slice'), findsNothing);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    expect(find.text('Create/Update Platform Prefab'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('platform_prefab_inspector_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('platform_prefab_scene_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('platform_prefab_display_card')),
      findsOneWidget,
    );
    expect(_dropdownByLabel('Atlas Slice'), findsNothing);

    await tester.tap(find.text('Obstacle Prefabs').first);
    await tester.pumpAndSettle();
    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);
  });

  testWidgets('obstacle tab stays atlas-slice only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    expect(_dropdownByLabel('Atlas Slice'), findsOneWidget);
    expect(find.text('crate_slice'), findsOneWidget);
    expect(find.text('ground_module'), findsNothing);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);

    await tester.tap(find.text('Platform Modules').first);
    await tester.pumpAndSettle();
    expect(find.text('ground_module'), findsWidgets);
    expect(find.text('Create/Update Platform Prefab'), findsNothing);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();
    expect(find.text('Create/Update Platform Prefab'), findsOneWidget);
  });

  testWidgets('obstacle create/edit flow is revision-safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.enterText(
      _textFieldByLabel('Prefab ID').first,
      'obstacle_box',
    );
    final obstacleUpsertButton = find.byKey(
      const ValueKey<String>('obstacle_prefab_upsert_button'),
    );
    await tester.tap(obstacleUpsertButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box"'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box" (rev=1'),
      findsOneWidget,
    );

    await tester.tap(find.text('Obstacle Prefabs').first);
    await tester.pumpAndSettle();
    await tester.tap(obstacleUpsertButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box"'),
      findsOneWidget,
    );
    // No-payload-change update keeps revision stable.
    expect(
      find.textContaining('Upserted obstacle prefab "obstacle_box" (rev=1'),
      findsOneWidget,
    );
  });

  testWidgets(
    'obstacle inspector can switch from edit mode to create-new mode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createPrefabAuthoringFixture();
      addTearDown(() {
        fixtureRoot.deleteSync(recursive: true);
      });

      final controller = await _pumpPrefabCreatorPage(
        tester,
        workspacePath: fixtureRoot.path,
      );

      expect(find.text('Creating new obstacle prefab'), findsOneWidget);
      expect(find.text('Create Prefab'), findsOneWidget);
      expect(find.text('Update Prefab'), findsNothing);

      await tester.enterText(
        _textFieldByLabel('Prefab ID').first,
        'obstacle_box',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('obstacle_prefab_upsert_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editing obstacle prefab "obstacle_box"'), findsOneWidget);
      expect(find.text('Update Prefab'), findsOneWidget);

      await tester.enterText(
        _textFieldByLabel('Prefab ID').first,
        'obstacle_box_variant',
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'obstacle_prefab_new_from_current_values_button',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Creating new obstacle prefab'), findsOneWidget);
      expect(find.text('Create Prefab'), findsOneWidget);
      expect(find.text('Update Prefab'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('obstacle_prefab_upsert_button')),
      );
      await tester.pumpAndSettle();

      final obstacleIds = _prefabScene(
        controller,
      ).data.prefabs.where((prefab) => prefab.kind == PrefabKind.obstacle).map(
        (prefab) => prefab.id,
      );
      expect(obstacleIds, containsAll(<String>['obstacle_box', 'obstacle_box_variant']));
      expect(obstacleIds.length, 2);
    },
  );

  testWidgets('obstacle prefab commits support undo and redo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    final controller = await _pumpPrefabCreatorPage(
      tester,
      workspacePath: fixtureRoot.path,
    );

    expect(find.text('No obstacle prefabs yet.'), findsOneWidget);
    expect(_prefabScene(controller).data.prefabs, isEmpty);

    await tester.enterText(
      _textFieldByLabel('Prefab ID').first,
      'obstacle_box',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('obstacle_prefab_upsert_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No obstacle prefabs yet.'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('obstacle_prefab_preview_obstacle_box'),
      ),
      findsOneWidget,
    );
    expect(
      _prefabScene(controller).data.prefabs.map((prefab) => prefab.id),
      contains('obstacle_box'),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_editor_undo_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No obstacle prefabs yet.'), findsOneWidget);
    expect(_prefabScene(controller).data.prefabs, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_editor_redo_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No obstacle prefabs yet.'), findsNothing);
    expect(
      _prefabScene(controller).data.prefabs.map((prefab) => prefab.id),
      contains('obstacle_box'),
    );
  });

  testWidgets('platform create/edit flow is revision-safe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      _textFieldByLabel('Platform Prefab ID').first,
      'platform_bridge',
    );
    await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted platform prefab "platform_bridge"'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Upserted platform prefab "platform_bridge" (rev=1'),
      findsOneWidget,
    );

    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upserted platform prefab "platform_bridge"'),
      findsOneWidget,
    );
    // No-payload-change update keeps revision stable.
    expect(
      find.textContaining('Upserted platform prefab "platform_bridge" (rev=1'),
      findsOneWidget,
    );
  });

  testWidgets('platform prefab commits support undo and redo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    final controller = await _pumpPrefabCreatorPage(
      tester,
      workspacePath: fixtureRoot.path,
    );

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    expect(_prefabScene(controller).data.prefabs, isEmpty);

    await tester.enterText(
      _textFieldByLabel('Platform Prefab ID').first,
      'platform_bridge',
    );
    await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(
      _prefabScene(
        controller,
      ).data.prefabs.where((prefab) => prefab.kind == PrefabKind.platform),
      hasLength(1),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_editor_undo_button')),
    );
    await tester.pumpAndSettle();

    expect(_prefabScene(controller).data.prefabs, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_editor_redo_button')),
    );
    await tester.pumpAndSettle();

    expect(
      _prefabScene(
        controller,
      ).data.prefabs.where((prefab) => prefab.kind == PrefabKind.platform),
      hasLength(1),
    );
  });

  testWidgets(
    'obstacle and platform form drafts preserve independent collider/anchor values',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createPrefabAuthoringFixture();
      addTearDown(() {
        fixtureRoot.deleteSync(recursive: true);
      });

      await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

      await tester.enterText(_textFieldByLabel('Anchor X (px)').first, '11');
      await tester.enterText(_textFieldByLabel('Anchor Y (px)').first, '12');
      await tester.enterText(_textFieldByLabel('Width').first, '31');
      await tester.enterText(_textFieldByLabel('Height').first, '32');

      await tester.tap(find.text('Platform Prefabs').first);
      await tester.pumpAndSettle();

      expect(_textFieldByLabel('Anchor X (px)').first, findsOneWidget);
      expect(_textFieldByLabel('Collider Width').first, findsOneWidget);
      expect(_textFieldValueByLabel(tester, 'Anchor X (px)'), isNot('11'));
      expect(_textFieldValueByLabel(tester, 'Anchor Y (px)'), isNot('12'));
      expect(_textFieldValueByLabel(tester, 'Collider Width'), isNot('31'));
      expect(_textFieldValueByLabel(tester, 'Collider Height'), isNot('32'));

      await tester.enterText(_textFieldByLabel('Anchor X (px)').first, '21');
      await tester.enterText(_textFieldByLabel('Anchor Y (px)').first, '22');
      await tester.enterText(_textFieldByLabel('Collider Width').first, '41');
      await tester.enterText(_textFieldByLabel('Collider Height').first, '42');

      await tester.tap(find.text('Obstacle Prefabs').first);
      await tester.pumpAndSettle();

      expect(_textFieldValueByLabel(tester, 'Anchor X (px)'), '11');
      expect(_textFieldValueByLabel(tester, 'Anchor Y (px)'), '12');
      expect(_textFieldValueByLabel(tester, 'Width'), '31');
      expect(_textFieldValueByLabel(tester, 'Height'), '32');

      await tester.tap(find.text('Platform Prefabs').first);
      await tester.pumpAndSettle();

      expect(_textFieldValueByLabel(tester, 'Anchor X (px)'), '21');
      expect(_textFieldValueByLabel(tester, 'Anchor Y (px)'), '22');
      expect(_textFieldValueByLabel(tester, 'Collider Width'), '41');
      expect(_textFieldValueByLabel(tester, 'Collider Height'), '42');
    },
  );

  testWidgets(
    'platform upsert does not overwrite a previously loaded obstacle prefab',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createPrefabAuthoringFixture();
      addTearDown(() {
        fixtureRoot.deleteSync(recursive: true);
      });

      await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

      await tester.enterText(
        _textFieldByLabel('Prefab ID').first,
        'obstacle_a',
      );
      final obstacleUpsertButton = find.byKey(
        const ValueKey<String>('obstacle_prefab_upsert_button'),
      );
      await tester.tap(obstacleUpsertButton);
      await tester.pumpAndSettle();

      expect(find.text('obstacle_a'), findsWidgets);

      await tester.tap(find.text('Platform Prefabs').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        _textFieldByLabel('Platform Prefab ID').first,
        'platform_a',
      );
      await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
      await tester.tap(find.text('Create/Update Platform Prefab'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Upserted platform prefab "platform_a"'),
        findsOneWidget,
      );

      await tester.tap(find.text('Obstacle Prefabs').first);
      await tester.pumpAndSettle();
      expect(find.text('obstacle_a'), findsWidgets);
    },
  );

  testWidgets('blocking validation surfaces coded errors on save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.ensureVisible(find.text('Save Definitions'));
    await tester.tap(find.text('Save Definitions'));
    await tester.pumpAndSettle();

    expect(find.textContaining('[prefab_slice_atlas_missing]'), findsOneWidget);
  });

  testWidgets(
    'module rename cascades prefab refs and delete blocks referenced module',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createPrefabAuthoringFixture();
      addTearDown(() {
        fixtureRoot.deleteSync(recursive: true);
      });

      await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

      await tester.tap(find.text('Platform Prefabs').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        _textFieldByLabel('Platform Prefab ID').first,
        'platform_ref',
      );
      await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
      await tester.tap(find.text('Create/Update Platform Prefab'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('source=platform_module:ground_module'),
        findsWidgets,
      );

      await tester.tap(find.text('Platform Modules').first);
      await tester.pumpAndSettle();
      await _openAdvancedModuleControls(tester);
      await tester.enterText(
        _textFieldByLabel('Platform Module ID').first,
        'ground_module_v2',
      );
      await tester.ensureVisible(find.text('Rename'));
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Renamed module "ground_module" -> "ground_module_v2"',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cannot delete module "ground_module_v2"'),
        findsOneWidget,
      );
      expect(find.textContaining('ground_module_v2'), findsWidgets);
    },
  );

  testWidgets(
    'platform module scene supports paint, erase, and move workflows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final fixtureRoot = _createPrefabAuthoringFixture();
      addTearDown(() {
        fixtureRoot.deleteSync(recursive: true);
      });

      await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

      await tester.tap(find.text('Platform Modules').first);
      await tester.pumpAndSettle();

      final sceneCanvas = find.byKey(
        const ValueKey<String>('platform_module_scene_canvas'),
      );
      expect(sceneCanvas, findsOneWidget);
      expect(find.textContaining('cells=1'), findsWidgets);

      final center = tester.getCenter(sceneCanvas);

      await tester.tap(find.byKey(const ValueKey<String>('module_tool_erase')));
      await tester.pumpAndSettle();

      for (final offset in <Offset>[
        Offset.zero,
        const Offset(10, 0),
        const Offset(-10, 0),
        const Offset(0, 10),
        const Offset(0, -10),
      ]) {
        await tester.tapAt(center + offset);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('cells=0'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey<String>('module_tool_paint')));
      await tester.pumpAndSettle();

      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(find.textContaining('Painted cell ('), findsOneWidget);
      expect(find.textContaining('cells=1'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey<String>('module_tool_move')));
      await tester.pumpAndSettle();

      await tester.dragFrom(center, const Offset(48, 0));
      await tester.pumpAndSettle();

      expect(find.textContaining('Moved cell (0,0) -> (1,0)'), findsOneWidget);
    },
  );

  testWidgets('platform prefabs tab can create a platform prefab for selected module', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    await _pumpPrefabCreatorPage(tester, workspacePath: fixtureRoot.path);

    await tester.tap(find.text('Platform Prefabs').first);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create/Update Platform Prefab'));
    await tester.tap(find.text('Create/Update Platform Prefab'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Upserted platform prefab'), findsOneWidget);
    expect(
      find.textContaining('source=platform_module:ground_module'),
      findsWidgets,
    );
  });

  testWidgets('platform module edits support undo and redo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final fixtureRoot = _createPrefabAuthoringFixture();
    addTearDown(() {
      fixtureRoot.deleteSync(recursive: true);
    });

    final controller = await _pumpPrefabCreatorPage(
      tester,
      workspacePath: fixtureRoot.path,
    );

    await tester.tap(find.text('Platform Modules').first);
    await tester.pumpAndSettle();

    final sceneCanvas = find.byKey(
      const ValueKey<String>('platform_module_scene_canvas'),
    );
    final center = tester.getCenter(sceneCanvas);

    expect(
      _prefabScene(controller).data.platformModules.single.cells,
      hasLength(1),
    );

    await tester.tap(find.byKey(const ValueKey<String>('module_tool_erase')));
    await tester.pumpAndSettle();
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    expect(_prefabScene(controller).data.platformModules.single.cells, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_editor_undo_button')),
    );
    await tester.pumpAndSettle();

    expect(
      _prefabScene(controller).data.platformModules.single.cells,
      hasLength(1),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('prefab_editor_redo_button')),
    );
    await tester.pumpAndSettle();

    expect(_prefabScene(controller).data.platformModules.single.cells, isEmpty);
  });
}

Future<EditorSessionController> _pumpPrefabCreatorPage(
  WidgetTester tester, {
  required String workspacePath,
  bool openObstacleTab = true,
}) async {
  final controller = EditorSessionController(
    pluginRegistry: AuthoringPluginRegistry(
      plugins: const <AuthoringDomainPlugin>[PrefabDomainPlugin()],
    ),
    initialPluginId: PrefabDomainPlugin.pluginId,
    initialWorkspacePath: workspacePath,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: PrefabCreatorPage(controller: controller)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  var settleBudget = 0;
  while (controller.isLoading && settleBudget < 200) {
    await tester.pump(const Duration(milliseconds: 20));
    settleBudget += 1;
  }
  await tester.pumpAndSettle();
  expect(
    controller.isLoading,
    isFalse,
    reason: 'Prefab editor should finish async load before assertions.',
  );

  expect(
    find.textContaining('Loaded prefab/tile authoring data'),
    findsOneWidget,
  );
  if (openObstacleTab) {
    await tester.tap(find.text('Obstacle Prefabs'));
    await tester.pumpAndSettle();
  }

  return controller;
}

Directory _createPrefabAuthoringFixture() {
  final root = Directory.systemTemp.createTempSync('prefab_creator_fixture_');
  final authoringDir = Directory(
    p.join(root.path, 'assets', 'authoring', 'level'),
  );
  authoringDir.createSync(recursive: true);
  final levelAssetsDir = Directory(
    p.join(root.path, 'assets', 'images', 'level'),
  );
  levelAssetsDir.createSync(recursive: true);

  const encoder = JsonEncoder.withIndent('  ');

  final prefabDefs = <String, Object?>{
    'schemaVersion': 2,
    'slices': <Object?>[
      <String, Object?>{
        'id': 'crate_slice',
        'sourceImagePath': 'assets/images/level/props/missing_props.png',
        'x': 0,
        'y': 0,
        'width': 32,
        'height': 32,
      },
    ],
    'prefabs': <Object?>[],
  };
  final tileDefs = <String, Object?>{
    'schemaVersion': 2,
    'tileSlices': <Object?>[
      <String, Object?>{
        'id': 'ground_tile',
        'sourceImagePath': 'assets/images/level/tileset/missing_tiles.png',
        'x': 0,
        'y': 0,
        'width': 16,
        'height': 16,
      },
    ],
    'platformModules': <Object?>[
      <String, Object?>{
        'id': 'ground_module',
        'tileSize': 16,
        'cells': <Object?>[
          <String, Object?>{'sliceId': 'ground_tile', 'gridX': 0, 'gridY': 0},
        ],
      },
    ],
  };

  File(
    p.join(authoringDir.path, 'prefab_defs.json'),
  ).writeAsStringSync('${encoder.convert(prefabDefs)}\n');
  File(
    p.join(authoringDir.path, 'tile_defs.json'),
  ).writeAsStringSync('${encoder.convert(tileDefs)}\n');

  return root;
}

Directory _createAtlasSlicerFixture() {
  final root = Directory.systemTemp.createTempSync('atlas_slicer_fixture_');
  final authoringDir = Directory(
    p.join(root.path, 'assets', 'authoring', 'level'),
  );
  authoringDir.createSync(recursive: true);

  final propsDir = Directory(
    p.join(root.path, 'assets', 'images', 'level', 'props'),
  );
  final tilesetDir = Directory(
    p.join(root.path, 'assets', 'images', 'level', 'tileset'),
  );
  propsDir.createSync(recursive: true);
  tilesetDir.createSync(recursive: true);

  _writeTestPng(p.join(propsDir.path, 'props_a.png'));
  _writeTestPng(p.join(propsDir.path, 'props_b.png'));
  _writeTestPng(p.join(tilesetDir.path, 'tiles_a.png'));
  _writeTestPng(p.join(tilesetDir.path, 'tiles_b.png'));

  const encoder = JsonEncoder.withIndent('  ');

  final prefabDefs = <String, Object?>{
    'schemaVersion': 2,
    'slices': <Object?>[
      <String, Object?>{
        'id': 'crate_slice',
        'sourceImagePath': 'assets/images/level/props/props_a.png',
        'x': 0,
        'y': 0,
        'width': 32,
        'height': 32,
      },
      <String, Object?>{
        'id': 'barrel_slice',
        'sourceImagePath': 'assets/images/level/props/props_b.png',
        'x': 16,
        'y': 0,
        'width': 32,
        'height': 32,
      },
    ],
    'prefabs': <Object?>[],
  };
  final tileDefs = <String, Object?>{
    'schemaVersion': 2,
    'tileSlices': <Object?>[
      <String, Object?>{
        'id': 'ground_tile',
        'sourceImagePath': 'assets/images/level/tileset/tiles_a.png',
        'x': 0,
        'y': 0,
        'width': 16,
        'height': 16,
      },
      <String, Object?>{
        'id': 'wall_tile',
        'sourceImagePath': 'assets/images/level/tileset/tiles_b.png',
        'x': 16,
        'y': 0,
        'width': 16,
        'height': 16,
      },
    ],
    'platformModules': <Object?>[
      <String, Object?>{
        'id': 'ground_module',
        'tileSize': 16,
        'cells': <Object?>[
          <String, Object?>{'sliceId': 'ground_tile', 'gridX': 0, 'gridY': 0},
        ],
      },
    ],
  };

  File(
    p.join(authoringDir.path, 'prefab_defs.json'),
  ).writeAsStringSync('${encoder.convert(prefabDefs)}\n');
  File(
    p.join(authoringDir.path, 'tile_defs.json'),
  ).writeAsStringSync('${encoder.convert(tileDefs)}\n');

  return root;
}

void _writeTestPng(String path) {
  File(path).writeAsBytesSync(base64Decode(_testAtlasPngBase64));
}

Future<void> _openAdvancedModuleControls(WidgetTester tester) async {
  if (_textFieldByLabel('Platform Module ID').evaluate().isNotEmpty) {
    return;
  }
  final tileFinder = find.byKey(
    const ValueKey<String>('platform_module_advanced_controls'),
  );
  expect(tileFinder, findsOneWidget);
  await tester.tap(
    find.descendant(
      of: tileFinder,
      matching: find.text('Advanced Module Controls'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownItem(
  WidgetTester tester, {
  required String label,
  required String itemText,
}) async {
  await tester.ensureVisible(_dropdownByLabel(label).first);
  await tester.tap(_dropdownByLabel(label).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(itemText).last);
  await tester.pumpAndSettle();
}

Finder _textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

String _textFieldValueByLabel(WidgetTester tester, String label) {
  final textField = tester.widget<TextField>(_textFieldByLabel(label).first);
  return textField.controller?.text ?? '';
}

Finder _dropdownByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField &&
        widget.decoration.labelText == label,
  );
}

PrefabScene _prefabScene(EditorSessionController controller) {
  final scene = controller.scene;
  expect(scene, isA<PrefabScene>());
  return scene! as PrefabScene;
}

const String _testAtlasPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAACLSURBVHhe7dAxAQAgEIDAL2caW34x3akAwy2MzN7zzIbBpgEMNg1gsGkAg00DGGwawGDTAAabBjDYNIDBpgEMNg1gsGkAg00DGGwawGDTAAabBjDYNIDBpgEMNg1gsGkAg00DGGwawGDTAAabBjDYNIDBpgEMNg1gsGkAg00DGGwawGDTAAabBjDYfEOJEkoWqqmTAAAAAElFTkSuQmCC';
