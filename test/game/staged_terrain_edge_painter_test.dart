import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:terrain_materials/terrain_materials.dart';

import 'package:rpg_runner/game/components/staged_terrain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('axis-aligned edge roles preserve world-facing source pixels', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final cases =
        <
          ({
            TerrainMaterialEdgeOrientation orientation,
            ui.Offset start,
            double length,
            double angle,
            ui.Offset expectedTopLeft,
          })
        >[
          (
            orientation: TerrainMaterialEdgeOrientation.top,
            start: const ui.Offset(2, 2),
            length: 2,
            angle: 0,
            expectedTopLeft: const ui.Offset(2, 2),
          ),
          (
            orientation: TerrainMaterialEdgeOrientation.rightWall,
            start: const ui.Offset(5, 3),
            length: 3,
            angle: math.pi / 2,
            expectedTopLeft: const ui.Offset(3, 3),
          ),
          (
            orientation: TerrainMaterialEdgeOrientation.underside,
            start: const ui.Offset(4, 5),
            length: 2,
            angle: math.pi,
            expectedTopLeft: const ui.Offset(2, 2),
          ),
          (
            orientation: TerrainMaterialEdgeOrientation.leftWall,
            start: const ui.Offset(2, 3),
            length: 3,
            angle: -math.pi / 2,
            expectedTopLeft: const ui.Offset(2, 0),
          ),
        ];

    for (final testCase in cases) {
      final actual = await _renderEdge(
        source,
        orientation: testCase.orientation,
        start: testCase.start,
        length: testCase.length,
        angle: testCase.angle,
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
  required double length,
  required double angle,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paintTerrainMaterialEdgeImage(
    canvas,
    start: start,
    length: length,
    angle: angle,
    image: source,
    anchorY: 0,
    orientation: orientation,
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
