import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/prefabCreator/platform_modules/widgets/platform_module_scene_view.dart';
import 'package:runner_editor/src/prefabs/models/models.dart';

void main() {
  testWidgets('dispatches paint, erase, and move callbacks by tool mode', (
    tester,
  ) async {
    final paintCalls = <_PaintCall>[];
    final eraseCalls = <_EraseCall>[];
    final moveCalls = <_MoveCall>[];

    await _pumpModuleScene(
      tester,
      module: _moduleWithSingleCell(),
      tileSlices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'ground_tile',
          sourceImagePath: 'assets/images/level/tileset/missing.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      onPaintCell: (gridX, gridY, sliceId) {
        paintCalls.add(
          _PaintCall(gridX: gridX, gridY: gridY, sliceId: sliceId),
        );
      },
      onEraseCell: (gridX, gridY) {
        eraseCalls.add(_EraseCall(gridX: gridX, gridY: gridY));
      },
      onMoveCell: (sourceGridX, sourceGridY, targetGridX, targetGridY) {
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

    final sceneCanvas = find.byKey(
      const ValueKey<String>('platform_module_scene_canvas'),
    );
    expect(sceneCanvas, findsOneWidget);
    _centerSceneScroll(tester);
    await tester.pump();
    final center = tester.getCenter(sceneCanvas);

    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(paintCalls, hasLength(1));
    expect(paintCalls.single.sliceId, 'ground_tile');

    await tester.tap(find.byKey(const ValueKey<String>('module_tool_erase')));
    await tester.pumpAndSettle();
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(eraseCalls, hasLength(1));

    await tester.tap(find.byKey(const ValueKey<String>('module_tool_move')));
    await tester.pumpAndSettle();
    await tester.dragFrom(center, const Offset(56, 0));
    await tester.pumpAndSettle();

    expect(moveCalls, hasLength(1));
    expect(moveCalls.single.sourceGridX, 0);
    expect(moveCalls.single.sourceGridY, 0);
    expect(
      moveCalls.single.targetGridX != moveCalls.single.sourceGridX ||
          moveCalls.single.targetGridY != moveCalls.single.sourceGridY,
      isTrue,
    );
  });

  testWidgets('stays interactive on compact mobile-sized viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final paintCalls = <_PaintCall>[];
    final eraseCalls = <_EraseCall>[];

    await _pumpModuleScene(
      tester,
      size: const Size(330, 260),
      module: _moduleWithSingleCell(),
      tileSlices: const <AtlasSliceDef>[
        AtlasSliceDef(
          id: 'ground_tile',
          sourceImagePath: 'assets/images/level/tileset/missing.png',
          x: 0,
          y: 0,
          width: 16,
          height: 16,
        ),
      ],
      onPaintCell: (gridX, gridY, sliceId) {
        paintCalls.add(
          _PaintCall(gridX: gridX, gridY: gridY, sliceId: sliceId),
        );
      },
      onEraseCell: (gridX, gridY) {
        eraseCalls.add(_EraseCall(gridX: gridX, gridY: gridY));
      },
      onMoveCell: (_, _, _, _) {},
    );

    final sceneCanvas = find.byKey(
      const ValueKey<String>('platform_module_scene_canvas'),
    );
    expect(sceneCanvas, findsOneWidget);
    _centerSceneScroll(tester);
    await tester.pump();
    final center = tester.getCenter(sceneCanvas);

    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(paintCalls, hasLength(1));

    await tester.tap(find.byKey(const ValueKey<String>('module_tool_erase')));
    await tester.pumpAndSettle();
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    expect(eraseCalls, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpModuleScene(
  WidgetTester tester, {
  required TileModuleDef module,
  required List<AtlasSliceDef> tileSlices,
  required void Function(int gridX, int gridY, String sliceId) onPaintCell,
  required void Function(int gridX, int gridY) onEraseCell,
  required void Function(
    int sourceGridX,
    int sourceGridY,
    int targetGridX,
    int targetGridY,
  )
  onMoveCell,
  Size size = const Size(720, 520),
}) async {
  var tool = PlatformModuleSceneTool.paint;
  final selectedTileSliceId = tileSlices.isEmpty ? null : tileSlices.first.id;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: StatefulBuilder(
              builder: (context, setState) {
                return PlatformModuleSceneView(
                  workspaceRootPath: Directory.systemTemp.path,
                  module: module,
                  tileSlices: tileSlices,
                  tool: tool,
                  selectedTileSliceId: selectedTileSliceId,
                  onToolChanged: (next) {
                    setState(() {
                      tool = next;
                    });
                  },
                  onPaintCell: onPaintCell,
                  onEraseCell: onEraseCell,
                  onMoveCell: onMoveCell,
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TileModuleDef _moduleWithSingleCell() {
  return const TileModuleDef(
    id: 'ground_module',
    revision: 1,
    status: TileModuleStatus.active,
    tileSize: 16,
    cells: <TileModuleCellDef>[
      TileModuleCellDef(sliceId: 'ground_tile', gridX: 0, gridY: 0),
    ],
  );
}

void _centerSceneScroll(WidgetTester tester) {
  final vertical = tester
      .widget<SingleChildScrollView>(
        find.byKey(
          const ValueKey<String>('platform_module_scene_vertical_scroll'),
        ),
      )
      .controller;
  final horizontal = tester
      .widget<SingleChildScrollView>(
        find.byKey(
          const ValueKey<String>('platform_module_scene_horizontal_scroll'),
        ),
      )
      .controller;
  if (vertical != null &&
      vertical.hasClients &&
      vertical.position.maxScrollExtent > 0) {
    vertical.jumpTo(vertical.position.maxScrollExtent * 0.5);
  }
  if (horizontal != null &&
      horizontal.hasClients &&
      horizontal.position.maxScrollExtent > 0) {
    horizontal.jumpTo(horizontal.position.maxScrollExtent * 0.5);
  }
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
