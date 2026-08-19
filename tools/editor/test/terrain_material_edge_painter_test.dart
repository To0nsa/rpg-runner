import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_editor/src/app/pages/shared/terrain_material_edge_painter.dart';
import 'package:terrain_materials/terrain_materials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('editor edge painter preserves world-facing source pixels', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final cases =
        <
          ({
            TerrainMaterialEdgeOrientation orientation,
            ui.Offset start,
            ui.Offset end,
            ui.Offset expectedTopLeft,
          })
        >[
          (
            orientation: TerrainMaterialEdgeOrientation.top,
            start: const ui.Offset(2, 2),
            end: const ui.Offset(4, 2),
            expectedTopLeft: const ui.Offset(2, 2),
          ),
          (
            orientation: TerrainMaterialEdgeOrientation.rightWall,
            start: const ui.Offset(5, 3),
            end: const ui.Offset(5, 6),
            expectedTopLeft: const ui.Offset(3, 3),
          ),
          (
            orientation: TerrainMaterialEdgeOrientation.underside,
            start: const ui.Offset(4, 5),
            end: const ui.Offset(2, 5),
            expectedTopLeft: const ui.Offset(2, 2),
          ),
          (
            orientation: TerrainMaterialEdgeOrientation.leftWall,
            start: const ui.Offset(2, 3),
            end: const ui.Offset(2, 0),
            expectedTopLeft: const ui.Offset(2, 0),
          ),
        ];

    for (final testCase in cases) {
      final actual = await _renderEdge(
        source,
        orientation: testCase.orientation,
        start: testCase.start,
        end: testCase.end,
      );
      final expected = await _renderSourceAt(source, testCase.expectedTopLeft);
      expect(
        await _rgbaBytes(actual),
        await _rgbaBytes(expected),
        reason: testCase.orientation.name,
      );
      actual.dispose();
      expected.dispose();
    }
  });

  test('underside cap is normalized into its world-facing corner', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final recorder = ui.PictureRecorder();
    paintTerrainMaterialCapImage(
      ui.Canvas(recorder),
      image: source,
      orientation: TerrainMaterialEdgeOrientation.underside,
      start: const ui.Offset(4, 5),
      end: const ui.Offset(2, 5),
      anchorX: 0,
      anchorY: 0,
      atEnd: false,
    );
    final picture = recorder.endRecording();
    final actual = await picture.toImage(8, 8);
    picture.dispose();
    addTearDown(actual.dispose);
    final expected = await _renderSourceAt(source, const ui.Offset(2, 2));
    addTearDown(expected.dispose);

    expect(await _rgbaBytes(actual), await _rgbaBytes(expected));
  });

  test('polygon clip contains edge bands at sloped corners', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final ownerPath = ui.Path()
      ..moveTo(2, 2)
      ..lineTo(6, 2)
      ..lineTo(6, 5)
      ..lineTo(4, 5)
      ..close();
    final rendered = await _renderEdge(
      source,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
      clipPath: ownerPath,
    );
    addTearDown(rendered.dispose);

    expect(await _alphaAt(rendered, 2, 4), 0);
    expect(await _alphaAt(rendered, 5, 3), greaterThan(0));
  });

  test('edge strip stops at the exact endpoint', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final rendered = await _renderEdge(
      source,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(4, 2),
    );
    addTearDown(rendered.dispose);

    expect(await _alphaAt(rendered, 3, 2), greaterThan(0));
    expect(await _alphaAt(rendered, 5, 2), 0);
  });
}

Future<ui.Image> _sourceImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  const colors = <ui.Color>[
    ui.Color(0xFFFF0000),
    ui.Color(0xFF00FF00),
    ui.Color(0xFF0000FF),
    ui.Color(0xFFFFFF00),
    ui.Color(0xFFFF00FF),
    ui.Color(0xFF00FFFF),
  ];
  for (var index = 0; index < colors.length; index += 1) {
    canvas.drawRect(
      ui.Rect.fromLTWH((index % 2).toDouble(), (index ~/ 2).toDouble(), 1, 1),
      ui.Paint()..color = colors[index],
    );
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(2, 3);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _renderEdge(
  ui.Image source, {
  required TerrainMaterialEdgeOrientation orientation,
  required ui.Offset start,
  required ui.Offset end,
  ui.Path? clipPath,
}) async {
  final recorder = ui.PictureRecorder();
  paintTerrainMaterialEdgeImage(
    ui.Canvas(recorder),
    image: source,
    orientation: orientation,
    start: start,
    end: end,
    anchorY: 0,
    clipPath: clipPath,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(8, 8);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _renderSourceAt(ui.Image source, ui.Offset offset) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImage(source, offset, ui.Paint());
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(8, 8);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _rgbaBytes(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

Future<int> _alphaAt(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.getUint8(((y * image.width) + x) * 4 + 3);
}
