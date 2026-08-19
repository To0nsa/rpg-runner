import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/staged_terrain.dart';
import 'package:terrain_materials/terrain_materials.dart';

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
      length: 4,
      angle: 0,
      clipPath: ownerPath,
    );
    addTearDown(rendered.dispose);

    expect(await _alphaAt(rendered, 2, 4), 0);
    expect(await _alphaAt(rendered, 5, 3), greaterThan(0));
  });

  test('source cap ownership clears lower terrain but not the scene', () async {
    final source = await _sourceImageWithTransparentTopLeft();
    addTearDown(source.dispose);
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFF0000FF), ui.BlendMode.src)
      ..saveLayer(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint())
      ..drawPath(ownerPath, ui.Paint()..color = const ui.Color(0xFFFF0000));
    paintTerrainMaterialCapImage(
      canvas,
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      image: source,
      anchorX: 0,
      anchorY: 0,
      atEnd: false,
      orientation: TerrainMaterialEdgeOrientation.top,
      clipPath: ownerPath,
      blendMode: ui.BlendMode.src,
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(8, 8);
    picture.dispose();
    addTearDown(rendered.dispose);

    expect(await _colorAt(rendered, 2, 2), const ui.Color(0xFF0000FF));
    expect(await _colorAt(rendered, 3, 2), const ui.Color(0xFF00FF00));
    expect(await _colorAt(rendered, 1, 1), const ui.Color(0xFFFF0000));
  });

  test('later cap alpha replaces an overlapping earlier cap', () async {
    final lower = await _solidImage(const ui.Color(0xFFFF0000), 2, 2);
    final higher = await _sourceImageWithTransparentTopLeft();
    addTearDown(lower.dispose);
    addTearDown(higher.dispose);
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFF0000FF), ui.BlendMode.src)
      ..saveLayer(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint());
    for (final image in <ui.Image>[lower, higher]) {
      paintTerrainMaterialCapImage(
        canvas,
        start: const ui.Offset(2, 2),
        length: 4,
        angle: 0,
        image: image,
        anchorX: 0,
        anchorY: 0,
        atEnd: false,
        orientation: TerrainMaterialEdgeOrientation.top,
        clipPath: ownerPath,
        blendMode: ui.BlendMode.src,
      );
    }
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(8, 8);
    picture.dispose();
    addTearDown(rendered.dispose);

    expect(await _colorAt(rendered, 2, 2), const ui.Color(0xFF0000FF));
    expect(await _colorAt(rendered, 3, 2), const ui.Color(0xFF00FF00));
  });

  test('dstOver backing fills internal repeat joins only', () async {
    final source = await _sourceImageWithTransparentTopLeft();
    addTearDown(source.dispose);
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final seamPath = terrainMaterialEdgeSeamBackingPath(
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      sourceWidth: 2,
      sourceHeight: 2,
      anchorY: 0,
      orientation: TerrainMaterialEdgeOrientation.top,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFF0000FF), ui.BlendMode.src)
      ..saveLayer(const ui.Rect.fromLTWH(0, 0, 8, 8), ui.Paint())
      ..drawPath(ownerPath, ui.Paint()..color = const ui.Color(0xFFFF0000));
    paintTerrainMaterialEdgeImage(
      canvas,
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      image: source,
      anchorY: 0,
      orientation: TerrainMaterialEdgeOrientation.top,
      clipPath: ownerPath,
      blendMode: ui.BlendMode.src,
    );
    canvas.save();
    canvas.clipPath(ownerPath);
    canvas.clipPath(seamPath);
    canvas.drawRect(
      ownerPath.getBounds(),
      ui.Paint()
        ..color = const ui.Color(0xFFFF0000)
        ..blendMode = ui.BlendMode.dstOver,
    );
    canvas.restore();
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(8, 8);
    picture.dispose();
    addTearDown(rendered.dispose);

    expect(await _colorAt(rendered, 2, 2), const ui.Color(0xFF0000FF));
    expect(await _colorAt(rendered, 4, 2), const ui.Color(0xFFFF0000));
    expect(await _colorAt(rendered, 3, 2), const ui.Color(0xFF00FF00));
  });

  test('fractional edge-to-fill join does not expose the scene', () async {
    final source = await _solidImage(const ui.Color(0xFF00FF00), 2, 2);
    addTearDown(source.dispose);
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTRB(2, 2.25, 8, 8));
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xFF0000FF), ui.BlendMode.src)
      ..saveLayer(const ui.Rect.fromLTRB(2, 2.25, 8, 8), ui.Paint())
      ..drawPath(ownerPath, ui.Paint()..color = const ui.Color(0xFFFF0000));
    paintTerrainMaterialEdgeImage(
      canvas,
      start: const ui.Offset(2, 2.25),
      length: 6,
      angle: 0,
      image: source,
      anchorY: 0,
      orientation: TerrainMaterialEdgeOrientation.top,
      clipPath: ownerPath,
      blendMode: ui.BlendMode.src,
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(10, 10);
    picture.dispose();
    addTearDown(rendered.dispose);

    expect(await _colorAt(rendered, 3, 3), const ui.Color(0xFF00FF00));
    final join = await _colorAt(rendered, 3, 4);
    expect(join.a, 1);
    expect(join.b, 0);
    expect(await _colorAt(rendered, 3, 5), const ui.Color(0xFFFF0000));
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

Future<ui.Image> _sourceImageWithTransparentTopLeft() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(1, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 1, 2, 1),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(2, 2);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _solidImage(ui.Color color, int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
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
  ui.Path? clipPath,
}) async {
  final recorder = ui.PictureRecorder();
  paintTerrainMaterialEdgeImage(
    ui.Canvas(recorder),
    start: start,
    length: length,
    angle: angle,
    image: source,
    anchorY: 0,
    orientation: orientation,
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

Future<ui.Color> _colorAt(ui.Image image, int x, int y) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final offset = ((y * image.width) + x) * 4;
  return ui.Color.fromARGB(
    data!.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  );
}
