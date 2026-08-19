import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_material_compositor.dart';
import 'package:terrain_materials/terrain_materials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'source ownership is watertight at a fractional polygon boundary',
    () async {
      final fill = await _solidImage(const ui.Color(0xFFFF0000));
      final edge = await _edgeImage();
      addTearDown(fill.dispose);
      addTearDown(edge.dispose);
      const fillRegion = TerrainMaterialImageRegion(
        assetPath: 'fill.png',
        x: 0,
        y: 0,
        width: 2,
        height: 2,
      );
      const edgeRegion = TerrainMaterialImageRegion(
        assetPath: 'edge.png',
        x: 0,
        y: 0,
        width: 2,
        height: 2,
      );
      const material = TerrainMaterialDefinition(
        key: 'test',
        displayName: 'Test',
        revision: 1,
        fill: fillRegion,
        top: TerrainMaterialEdgeProfile(
          base: TerrainMaterialEdgeLayer(region: edgeRegion, anchorY: 0),
        ),
      );
      final owner = ui.Path()..addRect(const ui.Rect.fromLTRB(2, 2.25, 8, 8));
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)
        ..drawColor(const ui.Color(0xFF0000FF), ui.BlendMode.src);
      paintTerrainMaterialComposition(
        canvas,
        ownerPath: owner,
        material: material,
        imagesByRegion: <TerrainMaterialImageRegion, ui.Image>{
          fillRegion: fill,
          edgeRegion: edge,
        },
        edges: <TerrainMaterialCompositorEdge>[
          TerrainMaterialCompositorEdge(
            profile: material.top,
            orientation: TerrainMaterialEdgeOrientation.top,
            start: ui.Offset(2, 2.25),
            end: ui.Offset(8, 2.25),
          ),
        ],
      );
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(10, 10);
      picture.dispose();
      addTearDown(rendered.dispose);

      expect(await _pixel(rendered, 2, 3), const ui.Color(0xFF0000FF));
      expect(await _pixel(rendered, 3, 3), const ui.Color(0xFF00FF00));
      final join = await _pixel(rendered, 3, 4);
      expect(join.a, 1);
      expect(join.b, 0);
      expect(await _pixel(rendered, 3, 5), const ui.Color(0xFFFF0000));
      expect(await _pixel(rendered, 1, 4), const ui.Color(0xFF0000FF));
    },
  );
}

Future<ui.Image> _solidImage(ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(
    recorder,
  ).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint()..color = color);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(2, 2);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _edgeImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 1),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(1, 1, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(2, 2);
  } finally {
    picture.dispose();
  }
}

Future<ui.Color> _pixel(ui.Image image, int x, int y) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = ((y * image.width) + x) * 4;
  return ui.Color.fromARGB(
    bytes!.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}
