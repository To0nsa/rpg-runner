import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/chunkCreator/widgets/chunk_scene_view.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/obstacle_prefabs/widgets/prefab_scene_view.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/platform_modules/widgets/platform_module_scene_view.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/shared/prefab_scene_values.dart';
import 'package:runner_editor/src/chunks/chunk_domain_models.dart';
import 'package:runner_editor/src/app/pages/shared/editor_scene_view_utils.dart';
import 'package:runner_editor/src/app/pages/shared/scene_input_utils.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  test(
    'prefab overlay projection preserves center-relative collider offsets',
    () {
      final values = prefabSceneValuesFromPrefab(
        PrefabDef(
          prefabKey: 'village_barrel_01',
          id: 'village_barrel_01',
          revision: 1,
          status: PrefabStatus.active,
          kind: PrefabKind.obstacle,
          visualSource: const PrefabVisualSource.atlasSlice(
            'village_barrel_01',
          ),
          anchorXPx: 16,
          anchorYPx: 23,
          colliders: const <PrefabColliderDef>[
            PrefabColliderDef(offsetX: 0, offsetY: 0, width: 18, height: 34),
          ],
        ),
      );

      expect(values, isNotNull);
      expect(values!.anchorX, 16);
      expect(values.anchorY, 23);
      expect(values.colliderOffsetX, 0);
      expect(values.colliderOffsetY, 0);
      expect(values.colliderWidth, 18);
      expect(values.colliderHeight, 34);
    },
  );

  test('shared scene zoom helpers snap and compare deterministically', () {
    expect(
      EditorSceneViewUtils.snapZoom(
        value: 1.06,
        min: 0.1,
        max: 12.0,
        step: 0.1,
      ),
      1.1,
    );
    expect(
      EditorSceneViewUtils.snapZoom(
        value: 0.01,
        min: 0.1,
        max: 12.0,
        step: 0.1,
      ),
      0.1,
    );
    expect(
      EditorSceneViewUtils.snapZoom(
        value: 12.6,
        min: 0.1,
        max: 12.0,
        step: 0.1,
      ),
      12.0,
    );
    expect(EditorSceneViewUtils.zoomValuesEqual(1.0, 1.0 + 0.0000001), isTrue);
    expect(EditorSceneViewUtils.zoomValuesEqual(1.0, 1.1), isFalse);
  });

  testWidgets('shared viewport centering helper recenters scroll state', (
    tester,
  ) async {
    final horizontal = ScrollController();
    final vertical = ScrollController();
    late StateSetter setViewportState;
    var shouldCenterViewport = false;
    addTearDown(() {
      horizontal.dispose();
      vertical.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setViewportState = setState;
              if (shouldCenterViewport) {
                EditorSceneViewUtils.scheduleViewportCentering(
                  context: context,
                  horizontal: horizontal,
                  vertical: vertical,
                );
              }
              return SizedBox(
                width: 220,
                height: 220,
                child: SingleChildScrollView(
                  controller: vertical,
                  child: SingleChildScrollView(
                    controller: horizontal,
                    scrollDirection: Axis.horizontal,
                    child: const SizedBox(width: 1200, height: 1200),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    horizontal.jumpTo(0);
    vertical.jumpTo(0);
    await tester.pump();

    setViewportState(() {
      shouldCenterViewport = true;
    });
    await tester.pump();
    await tester.pump();

    expect(horizontal.offset, horizontal.position.maxScrollExtent * 0.5);
    expect(vertical.offset, vertical.position.maxScrollExtent * 0.5);
  });

  testWidgets('prefab scene uses shared Ctrl+drag pan and Ctrl+scroll zoom', (
    tester,
  ) async {
    final workspaceRoot = _repoRootPath();
    expect(
      File(
        p.join(
          workspaceRoot,
          'assets',
          'images',
          'level',
          'props',
          'TX Village Props.png',
        ),
      ).existsSync(),
      isTrue,
    );
    const slice = AtlasSliceDef(
      id: 'prefab_slice',
      sourceImagePath: 'assets/images/level/props/TX Village Props.png',
      x: 0,
      y: 0,
      width: 128,
      height: 128,
    );
    var values = const PrefabSceneValues(
      anchorX: 0,
      anchorY: 0,
      colliderOffsetX: 0,
      colliderOffsetY: 0,
      colliderWidth: 64,
      colliderHeight: 64,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 620,
            height: 420,
            child: PrefabSceneView(
              workspaceRootPath: workspaceRoot,
              slice: slice,
              values: values,
              onChanged: (next) {
                values = next;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 40; i += 1) {
      if (find
          .byKey(const ValueKey<String>('prefab_scene_canvas'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    final canvas = find.byKey(const ValueKey<String>('prefab_scene_canvas'));
    expect(canvas, findsOneWidget);
    final horizontal = _scrollControllerByKey(
      tester,
      'prefab_scene_horizontal_scroll',
    );
    final vertical = _scrollControllerByKey(
      tester,
      'prefab_scene_vertical_scroll',
    );
    _centerScrollControllers(horizontal: horizontal, vertical: vertical);
    await tester.pump();

    final panStartX = horizontal.offset;
    final panStartY = vertical.offset;
    await _ctrlDragCanvas(tester, canvas, const Offset(-120, -90));
    expect(
      horizontal.offset != panStartX || vertical.offset != panStartY,
      isTrue,
    );

    final zoomBefore = _zoomFieldValue(tester);
    await _ctrlScrollAt(tester, canvas, deltaY: -120);
    final zoomAfter = _zoomFieldValue(tester);
    expect(zoomAfter, isNot(zoomBefore));
    expect(values.colliderWidth, 64);
  });

  testWidgets(
    'platform module scene shares pan/zoom controls and tool-driven primary drag',
    (tester) async {
      final workspaceRoot = _repoRootPath();
      final paintCalls = <_PaintCall>[];
      final eraseCalls = <_EraseCall>[];
      final moveCalls = <_MoveCall>[];
      var tool = PlatformModuleSceneTool.paint;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 680,
              height: 460,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return PlatformModuleSceneView(
                    workspaceRootPath: workspaceRoot,
                    module: const TileModuleDef(
                      id: 'ground_module',
                      revision: 1,
                      status: TileModuleStatus.active,
                      tileSize: 16,
                      cells: <TileModuleCellDef>[
                        TileModuleCellDef(
                          sliceId: 'ground_tile',
                          gridX: 0,
                          gridY: 0,
                        ),
                      ],
                    ),
                    tileSlices: const <AtlasSliceDef>[
                      AtlasSliceDef(
                        id: 'ground_tile',
                        sourceImagePath:
                            'assets/images/level/tileset/TX Tileset Ground.png',
                        x: 0,
                        y: 0,
                        width: 128,
                        height: 128,
                      ),
                    ],
                    tool: tool,
                    selectedTileSliceId: 'ground_tile',
                    onToolChanged: (next) {
                      setState(() {
                        tool = next;
                      });
                    },
                    onPaintCell: (gridX, gridY, sliceId) {
                      paintCalls.add(
                        _PaintCall(
                          gridX: gridX,
                          gridY: gridY,
                          sliceId: sliceId,
                        ),
                      );
                    },
                    onEraseCell: (gridX, gridY) {
                      eraseCalls.add(_EraseCall(gridX: gridX, gridY: gridY));
                    },
                    onMoveCell:
                        (sourceGridX, sourceGridY, targetGridX, targetGridY) {
                          moveCalls.add(
                            _MoveCall(
                              sourceGridX: sourceGridX,
                              sourceGridY: sourceGridY,
                              targetGridX: targetGridX,
                              targetGridY: targetGridY,
                            ),
                          );
                        },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final canvas = find.byKey(
        const ValueKey<String>('platform_module_scene_canvas'),
      );
      expect(canvas, findsOneWidget);
      final horizontal = _scrollControllerByKey(
        tester,
        'platform_module_scene_horizontal_scroll',
      );
      final vertical = _scrollControllerByKey(
        tester,
        'platform_module_scene_vertical_scroll',
      );
      _centerScrollControllers(horizontal: horizontal, vertical: vertical);
      await tester.pump();
      final center = tester.getCenter(canvas);

      final panStartX = horizontal.offset;
      final panStartY = vertical.offset;
      await _ctrlDragCanvas(tester, canvas, const Offset(-120, -90));
      expect(
        horizontal.offset != panStartX || vertical.offset != panStartY,
        isTrue,
      );

      final zoomBefore = _zoomFieldValue(tester);
      await _ctrlScrollAt(tester, canvas, deltaY: -120);
      final zoomAfter = _zoomFieldValue(tester);
      expect(zoomAfter, isNot(zoomBefore));

      await tester.tap(find.byKey(const ValueKey<String>('module_tool_erase')));
      await tester.pumpAndSettle();
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(eraseCalls, hasLength(1));

      await tester.tap(find.byKey(const ValueKey<String>('module_tool_paint')));
      await tester.pumpAndSettle();
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(paintCalls, hasLength(1));

      await tester.tap(find.byKey(const ValueKey<String>('module_tool_move')));
      await tester.pumpAndSettle();
      await tester.dragFrom(center, const Offset(64, 0));
      await tester.pumpAndSettle();
      expect(moveCalls, hasLength(1));
      expect(moveCalls.single.sourceGridX, 0);
      expect(moveCalls.single.sourceGridY, 0);
    },
  );

  testWidgets(
    'chunk scene shares pan/zoom controls and dispatches place/select',
    (tester) async {
      final workspaceRoot = _repoRootPath();
      final placeCalls = <Offset>[];
      final selectCalls = <String?>[];
      var tool = ChunkSceneTool.place;
      var selectedPlacementKey = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 820,
              height: 520,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ChunkSceneView(
                    workspaceRootPath: workspaceRoot,
                    chunk: const LevelChunkDef(
                      chunkKey: 'chunk_scene',
                      id: 'chunk_scene',
                      revision: 1,
                      schemaVersion: 1,
                      levelId: 'field',
                      tileSize: 16,
                      width: 600,
                      height: 270,
                      difficulty: chunkDifficultyNormal,
                      prefabs: <PlacedPrefabDef>[
                        PlacedPrefabDef(
                          prefabId: 'village_crate_01',
                          prefabKey: 'village_crate_01',
                          x: 304,
                          y: 128,
                        ),
                      ],
                      groundProfile: GroundProfileDef(
                        kind: groundProfileKindFlat,
                        topY: 224,
                      ),
                    ),
                    prefabData: PrefabData(
                      prefabSlices: const <AtlasSliceDef>[
                        AtlasSliceDef(
                          id: 'village_crate_01',
                          sourceImagePath:
                              'assets/images/level/props/TX Village Props.png',
                          x: 32,
                          y: 16,
                          width: 64,
                          height: 52,
                        ),
                      ],
                      prefabs: <PrefabDef>[
                        PrefabDef(
                          prefabKey: 'village_crate_01',
                          id: 'village_crate_01',
                          revision: 1,
                          status: PrefabStatus.active,
                          kind: PrefabKind.obstacle,
                          visualSource: const PrefabVisualSource.atlasSlice(
                            'village_crate_01',
                          ),
                          anchorXPx: 34,
                          anchorYPx: 26,
                          colliders: const <PrefabColliderDef>[
                            PrefabColliderDef(
                              offsetX: -1,
                              offsetY: 0,
                              width: 45,
                              height: 45,
                            ),
                          ],
                        ),
                      ],
                    ),
                    runtimeGridSnap: 16.0,
                    tool: tool,
                    placeMode: ChunkScenePlaceMode.prefab,
                    placeSnapToGrid: true,
                    selectedPalettePrefabKey: 'village_crate_01',
                    selectedPlacementKey: selectedPlacementKey,
                    selectedEnemyMarkerId: 'grojib',
                    selectedMarkerKey: null,
                    onToolChanged: (next) {
                      setState(() {
                        tool = next;
                      });
                    },
                    onPlacePrefab: (x, y) {
                      placeCalls.add(Offset(x.toDouble(), y.toDouble()));
                    },
                    onSelectPlacement: (selectionKey) {
                      selectCalls.add(selectionKey);
                      setState(() {
                        selectedPlacementKey = selectionKey ?? '';
                      });
                    },
                    onMovePlacement: (_, _, _) {},
                    onCommitPlacementMove: () {},
                    onRemovePlacement: (_) {},
                    onPlaceMarker: (_, _) {},
                    onSelectMarker: (_) {},
                    onMoveMarker: (_, _, _) {},
                    onCommitMarkerMove: () {},
                    onRemoveMarker: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final canvas = find.byKey(const ValueKey<String>('chunk_scene_canvas'));
      expect(canvas, findsOneWidget);
      final horizontal = _scrollControllerByKey(
        tester,
        'chunk_scene_horizontal_scroll',
      );
      final vertical = _scrollControllerByKey(
        tester,
        'chunk_scene_vertical_scroll',
      );
      _centerScrollControllers(horizontal: horizontal, vertical: vertical);
      await tester.pump();
      final center = tester.getCenter(canvas);

      final panStartX = horizontal.offset;
      final panStartY = vertical.offset;
      await _ctrlDragCanvas(tester, canvas, const Offset(-120, -90));
      expect(
        horizontal.offset != panStartX || vertical.offset != panStartY,
        isTrue,
      );

      final zoomBefore = _zoomFieldValue(tester);
      await _ctrlScrollAt(tester, canvas, deltaY: -120);
      final zoomAfter = _zoomFieldValue(tester);
      expect(zoomAfter, isNot(zoomBefore));

      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(placeCalls, isNotEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('chunk_scene_tool_select')),
      );
      await tester.pumpAndSettle();
      _centerScrollControllers(horizontal: horizontal, vertical: vertical);
      await tester.pump();
      final selectCenter = tester.getCenter(canvas);
      final currentZoom = double.parse(_zoomFieldValue(tester)) / 100.0;
      await tester.tapAt(
        selectCenter + Offset(4 * currentZoom, 50 * currentZoom),
      );
      await tester.pumpAndSettle();
      expect(selectCalls.whereType<String>(), isNotEmpty);
    },
  );

  testWidgets(
    'chunk scene drag refreshes selection key between move callbacks',
    (tester) async {
      final workspaceRoot = _repoRootPath();
      final moveKeys = <String>[];
      var tool = ChunkSceneTool.select;
      var selectedPlacementKey = buildChunkPlacedPrefabSelectionKey(
        'village_crate_01',
        x: 304,
        y: 128,
        ordinalAtLocation: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 820,
              height: 520,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ChunkSceneView(
                    workspaceRootPath: workspaceRoot,
                    chunk: const LevelChunkDef(
                      chunkKey: 'chunk_scene',
                      id: 'chunk_scene',
                      revision: 1,
                      schemaVersion: 1,
                      levelId: 'field',
                      tileSize: 16,
                      width: 600,
                      height: 270,
                      difficulty: chunkDifficultyNormal,
                      prefabs: <PlacedPrefabDef>[
                        PlacedPrefabDef(
                          prefabId: 'village_crate_01',
                          prefabKey: 'village_crate_01',
                          x: 304,
                          y: 128,
                        ),
                      ],
                      groundProfile: GroundProfileDef(
                        kind: groundProfileKindFlat,
                        topY: 224,
                      ),
                    ),
                    prefabData: PrefabData(
                      prefabSlices: const <AtlasSliceDef>[
                        AtlasSliceDef(
                          id: 'village_crate_01',
                          sourceImagePath:
                              'assets/images/level/props/TX Village Props.png',
                          x: 32,
                          y: 16,
                          width: 64,
                          height: 52,
                        ),
                      ],
                      prefabs: <PrefabDef>[
                        PrefabDef(
                          prefabKey: 'village_crate_01',
                          id: 'village_crate_01',
                          revision: 1,
                          status: PrefabStatus.active,
                          kind: PrefabKind.obstacle,
                          visualSource: const PrefabVisualSource.atlasSlice(
                            'village_crate_01',
                          ),
                          anchorXPx: 34,
                          anchorYPx: 26,
                          colliders: const <PrefabColliderDef>[
                            PrefabColliderDef(
                              offsetX: -1,
                              offsetY: 0,
                              width: 45,
                              height: 45,
                            ),
                          ],
                        ),
                      ],
                    ),
                    runtimeGridSnap: 16.0,
                    tool: tool,
                    placeMode: ChunkScenePlaceMode.prefab,
                    placeSnapToGrid: true,
                    selectedPalettePrefabKey: 'village_crate_01',
                    selectedPlacementKey: selectedPlacementKey,
                    selectedEnemyMarkerId: 'grojib',
                    selectedMarkerKey: null,
                    onToolChanged: (next) {
                      setState(() {
                        tool = next;
                      });
                    },
                    onPlacePrefab: (_, _) {},
                    onSelectPlacement: (selectionKey) {
                      setState(() {
                        selectedPlacementKey = selectionKey ?? '';
                      });
                    },
                    onMovePlacement: (selectionKey, x, y) {
                      moveKeys.add(selectionKey);
                      setState(() {
                        selectedPlacementKey =
                            buildChunkPlacedPrefabSelectionKey(
                              'village_crate_01',
                              x: x,
                              y: y,
                              ordinalAtLocation: 0,
                            );
                      });
                    },
                    onCommitPlacementMove: () {},
                    onRemovePlacement: (_) {},
                    onPlaceMarker: (_, _) {},
                    onSelectMarker: (_) {},
                    onMoveMarker: (_, _, _) {},
                    onCommitMarkerMove: () {},
                    onRemoveMarker: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final canvas = find.byKey(const ValueKey<String>('chunk_scene_canvas'));
      expect(canvas, findsOneWidget);
      final horizontal = _scrollControllerByKey(
        tester,
        'chunk_scene_horizontal_scroll',
      );
      final vertical = _scrollControllerByKey(
        tester,
        'chunk_scene_vertical_scroll',
      );
      _centerScrollControllers(horizontal: horizontal, vertical: vertical);
      await tester.pump();

      final center = tester.getCenter(canvas);
      final currentZoom = double.parse(_zoomFieldValue(tester)) / 100.0;
      final placementPoint = center + Offset(4 * currentZoom, 50 * currentZoom);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.down(placementPoint);
      await gesture.moveBy(Offset(16 * currentZoom, 0));
      await tester.pump();
      await gesture.moveBy(Offset(16 * currentZoom, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveKeys, hasLength(greaterThanOrEqualTo(2)));
      expect(moveKeys.first, 'village_crate_01|304|128|0');
      expect(moveKeys[1], 'village_crate_01|320|128|0');
    },
  );

  testWidgets(
    'shared scene input utils keep deterministic control primitives',
    (tester) async {
      final horizontal = ScrollController();
      final vertical = ScrollController();
      addTearDown(() {
        horizontal.dispose();
        vertical.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 220,
              child: SingleChildScrollView(
                controller: vertical,
                child: SingleChildScrollView(
                  controller: horizontal,
                  scrollDirection: Axis.horizontal,
                  child: const SizedBox(width: 1200, height: 1200),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      horizontal.jumpTo(400);
      vertical.jumpTo(400);
      await tester.pump();

      SceneInputUtils.panScrollControllers(
        horizontal: horizontal,
        vertical: vertical,
        pointerDelta: const Offset(-50, 25),
      );
      expect(horizontal.offset, 450);
      expect(vertical.offset, 375);

      expect(SceneInputUtils.zoomStepsFromScrollDeltaY(0), 0);
      expect(SceneInputUtils.zoomStepsFromScrollDeltaY(1), 1);
      expect(SceneInputUtils.zoomStepsFromScrollDeltaY(120), 1);
      expect(SceneInputUtils.zoomStepsFromScrollDeltaY(240), 2);
    },
  );
}

ScrollController _scrollControllerByKey(WidgetTester tester, String key) {
  final view = tester.widget<SingleChildScrollView>(
    find.byKey(ValueKey<String>(key)),
  );
  final controller = view.controller;
  expect(controller, isNotNull);
  expect(controller!.hasClients, isTrue);
  return controller;
}

void _centerScrollControllers({
  required ScrollController horizontal,
  required ScrollController vertical,
}) {
  if (horizontal.position.maxScrollExtent > 0) {
    horizontal.jumpTo(horizontal.position.maxScrollExtent * 0.5);
  }
  if (vertical.position.maxScrollExtent > 0) {
    vertical.jumpTo(vertical.position.maxScrollExtent * 0.5);
  }
}

Future<void> _ctrlDragCanvas(
  WidgetTester tester,
  Finder canvas,
  Offset delta,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kPrimaryMouseButton,
  );
  await gesture.down(tester.getCenter(canvas));
  await gesture.moveBy(delta);
  await gesture.up();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _ctrlScrollAt(
  WidgetTester tester,
  Finder target, {
  required double deltaY,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  tester.binding.handlePointerEvent(
    PointerScrollEvent(
      position: tester.getCenter(target),
      scrollDelta: Offset(0, deltaY),
    ),
  );
  await tester.pumpAndSettle();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

String _zoomFieldValue(WidgetTester tester) {
  final zoomField = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Zoom',
  );
  expect(zoomField, findsOneWidget);
  final field = tester.widget<TextField>(zoomField);
  return field.controller?.text ?? '';
}

String _repoRootPath() {
  final candidates = <String>[
    Directory.current.path,
    p.join(Directory.current.path, '..'),
    p.join(Directory.current.path, '..', '..'),
    p.join(Directory.current.path, '..', '..', '..'),
  ];
  for (final candidate in candidates) {
    final root = p.normalize(candidate);
    final propsPath = p.join(
      root,
      'assets',
      'images',
      'level',
      'props',
      'TX Village Props.png',
    );
    if (File(propsPath).existsSync()) {
      return root;
    }
  }
  throw StateError(
    'Could not resolve repo root for scene control parity tests.',
  );
}

class _PaintCall {
  const _PaintCall({
    required this.gridX,
    required this.gridY,
    required this.sliceId,
  });

  final int gridX;
  final int gridY;
  final String sliceId;
}

class _EraseCall {
  const _EraseCall({required this.gridX, required this.gridY});

  final int gridX;
  final int gridY;
}

class _MoveCall {
  const _MoveCall({
    required this.sourceGridX,
    required this.sourceGridY,
    required this.targetGridX,
    required this.targetGridY,
  });

  final int sourceGridX;
  final int sourceGridY;
  final int targetGridX;
  final int targetGridY;
}
