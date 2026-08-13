import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/atlas_image_viewport.dart';
import 'package:runner_editor/src/atlas/atlas_grid.dart';
import 'package:runner_editor/src/atlas/atlas_pixel_rect.dart';

void main() {
  testWidgets('auto-slice click selects the complete grid cell', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('atlas_viewport_');
    addTearDown(() => root.deleteSync(recursive: true));
    final image = File('${root.path}${Platform.pathSeparator}atlas.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
        ),
      );
    final horizontal = ScrollController();
    final vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    AtlasPixelRect? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: AtlasImageViewport(
              workspaceRootPath: root.path,
              sourceImagePath: image.uri.pathSegments.last,
              imageWidth: 64,
              imageHeight: 64,
              zoom: 2,
              zoomMin: 0.2,
              zoomMax: 24,
              zoomStep: 0.2,
              autoSliceEnabled: true,
              gridSettings: const AtlasGridSettings(),
              selection: null,
              horizontalScrollController: horizontal,
              verticalScrollController: vertical,
              onZoomChanged: (_) {},
              onSelectionChanged: (rect) => selected = rect,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final canvas = find.byKey(const ValueKey<String>('atlas_scene_canvas'));
    await tester.tapAt(tester.getTopLeft(canvas) + const Offset(40, 40));
    await tester.pump();

    expect(selected, const AtlasPixelRect(x: 0, y: 0, width: 32, height: 32));
  });
}
