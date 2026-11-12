import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/editor_scene_viewport.dart';

void main() {
  test(
    'centered scenes share zoom, inverse coordinates and navigation restore',
    () {
      final view = EditorSceneViewportController();
      addTearDown(view.dispose);
      view.setZoom(.5);
      var layout = view.layout(
        viewport: const Size(800, 600),
        scene: const Size(600, 270),
      );
      expect(layout.origin, const Offset(250, 232.5));
      expect(layout.toWorld(const Offset(400, 300)), const Offset(300, 135));
      view.panBy(const Offset(-25, 40));
      layout = view.layout(
        viewport: const Size(800, 600),
        scene: const Size(600, 270),
      );
      expect(layout.toWorld(const Offset(375, 340)), const Offset(300, 135));
      view.restore(zoom: 1.75, pan: const Offset(12, 24));
      expect(view.zoom, 1.75);
      expect(view.pan, const Offset(12, 24));
      view.setZoom(100);
      expect(view.zoom, 8);
      view.setZoom(.01);
      expect(view.zoom, .25);
      view.reset();
      expect(view.zoom, 1);
      expect(view.pan, Offset.zero);
    },
  );

  testWidgets('bounded scenes share centering, scroll limits and reset', (
    tester,
  ) async {
    final view = EditorSceneViewportController(
      scrollable: true,
      alignment: Alignment.centerLeft,
    );
    addTearDown(view.dispose);
    const viewport = Size(300, 200), scene = Size(1200, 400);
    Future<void> pump() async {
      final layout = view.layout(viewport: viewport, scene: scene);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: viewport.width,
              height: viewport.height,
              child: SingleChildScrollView(
                controller: view.vertical,
                padding: EdgeInsets.only(
                  top: layout.padding.top,
                  bottom: layout.padding.bottom,
                ),
                child: SizedBox(
                  height: layout.contentSize.height,
                  child: SingleChildScrollView(
                    controller: view.horizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: layout.contentSize.width),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump();
    view.panBy(const Offset(-100, -50));
    final layout = view.layout(viewport: viewport, scene: scene);
    expect(layout.origin, const Offset(-100, -50));
    expect(layout.toWorld(const Offset(20, 30)), const Offset(120, 80));
    view.panBy(const Offset(-10000, -10000));
    expect(view.horizontal!.offset, 900);
    expect(view.vertical!.offset, 200);
    view.setZoom(.25);
    await pump();
    expect(view.horizontal!.offset, 0);
    expect(view.vertical!.offset, 0);
    final reduced = view.layout(viewport: viewport, scene: scene);
    expect(reduced.origin, const Offset(0, 50));
    expect(reduced.toWorld(const Offset(150, 100)), const Offset(600, 200));
    view.reset();
    await pump();
    expect(view.zoom, 1);
    expect(view.horizontal!.offset, 0);
    expect(view.vertical!.offset, 0);
  });

  test('height fit centers the full route without fitting its width', () {
    final view = EditorSceneViewportController(
      scrollable: true,
      fit: EditorSceneFit.height,
      alignment: Alignment.centerLeft,
    );
    addTearDown(view.dispose);
    view.setZoom(.5);
    final layout = view.layout(
      viewport: const Size(800, 540),
      scene: const Size(9600, 270),
    );
    expect(layout.scale, 1);
    expect(layout.origin, const Offset(0, 135));
    expect(layout.contentSize, const Size(9600, 270));
  });

  testWidgets(
    'shared pointer ownership consumes wheel once and isolates edit drags',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      var zoomSteps = 0, edits = 0, cancels = 0;
      var pan = Offset.zero;
      var canNavigate = true;
      final region = find.byType(EditorScenePointerRegion);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 240,
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    controller: scroll,
                    child: const SizedBox(height: 1200),
                  ),
                  EditorScenePointerRegion(
                    behavior: HitTestBehavior.translucent,
                    canNavigate: () => canNavigate,
                    onZoomSteps: (steps) => zoomSteps += steps,
                    onPanDelta: (delta) => pan += delta,
                    onScrollDelta: (delta) =>
                        scroll.jumpTo(scroll.offset + delta.dy),
                    onPointerMove: (_) => edits++,
                    onPointerCancel: (_) => cancels++,
                    child: const SizedBox.expand(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(region);
      Future<void> wheel(double dy) => tester.sendEventToBinding(
        PointerScrollEvent(position: center, scrollDelta: Offset(0, dy)),
      );
      await wheel(120);
      await tester.pump();
      expect(
        scroll.offset,
        120,
      ); // The underlying Scrollable must not also scroll.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await wheel(-120);
      expect(zoomSteps, 1);
      expect(scroll.offset, 120);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.down(center);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await mouse.moveBy(const Offset(12, 6));
      await wheel(-120);
      expect(edits, 1);
      expect(pan, Offset.zero);
      expect(zoomSteps, 1);
      expect(scroll.offset, 120);
      await mouse.cancel();
      expect(cancels, 1);

      await mouse.down(center);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await mouse.moveBy(const Offset(20, 10));
      expect(pan, const Offset(20, 10));
      expect(edits, 1);
      await mouse.up();
      canNavigate = false;
      await wheel(120);
      expect(scroll.offset, 120);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
