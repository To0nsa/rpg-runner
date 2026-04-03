import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:runner_editor/src/app/pages/prefabCreator/widgets/platform_module_scene_view.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/widgets/prefab_scene_values.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/widgets/prefab_scene_view.dart';
import 'package:runner_editor/src/app/pages/shared/scene_input_utils.dart';
import 'package:runner_editor/src/prefabs/prefab_models.dart';

void main() {
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
