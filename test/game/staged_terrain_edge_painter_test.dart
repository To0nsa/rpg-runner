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

  test('underside cap preserves its world-facing source pixels', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final recorder = ui.PictureRecorder();
    paintTerrainMaterialCapImage(
      ui.Canvas(recorder),
      start: const ui.Offset(4, 5),
      length: 2,
      angle: math.pi,
      image: source,
      anchorX: 0,
      anchorY: 0,
      atEnd: false,
      orientation: TerrainMaterialEdgeOrientation.underside,
    );
    final picture = recorder.endRecording();
    final actual = await picture.toImage(8, 8);
    picture.dispose();
    final expected = await _renderSourceAt(source, const ui.Offset(2, 2));
    addTearDown(actual.dispose);
    addTearDown(expected.dispose);

    expect(await _rgbaBytes(actual), await _rgbaBytes(expected));
  });

  test('polygon clip contains edge bands and caps at sloped corners', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final ownerPath = ui.Path()
      ..moveTo(2, 2)
      ..lineTo(6, 2)
      ..lineTo(6, 5)
      ..lineTo(4, 5)
      ..close();
    final unclippedEdge = await _renderEdge(
      source,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
    );
    final clippedEdge = await _renderEdge(
      source,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      clipPath: ownerPath,
    );
    final clippedCap = await _renderCap(
      source,
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      clipPath: ownerPath,
    );
    addTearDown(unclippedEdge.dispose);
    addTearDown(clippedEdge.dispose);
    addTearDown(clippedCap.dispose);

    expect(await _alphaAt(unclippedEdge, 2, 4), greaterThan(0));
    expect(await _alphaAt(clippedEdge, 2, 4), 0);
    expect(await _alphaAt(clippedCap, 2, 4), 0);
    expect(await _alphaAt(clippedEdge, 5, 3), greaterThan(0));
    expect(await _alphaAt(clippedCap, 3, 3), greaterThan(0));
  });

  test('edge strip stops at the exact endpoint', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    final rendered = await _renderEdge(
      source,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      length: 2,
      angle: 0,
    );
    addTearDown(rendered.dispose);

    expect(await _alphaAt(rendered, 3, 2), greaterThan(0));
    expect(await _alphaAt(rendered, 5, 2), 0);
  });

  test(
    'cap footprint prevents lower art leaking through transparency',
    () async {
      final source = await _sourceImageWithTransparentTopLeft();
      addTearDown(source.dispose);
      final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
      final footprint = terrainMaterialCapFootprintPath(
        start: const ui.Offset(2, 2),
        length: 4,
        angle: 0,
        sourceWidth: 2,
        sourceHeight: 2,
        anchorX: 0,
        anchorY: 0,
        orientation: TerrainMaterialEdgeOrientation.top,
        atEnd: false,
      );
      final lowerPriorityClip = terrainMaterialLowerPriorityClipPath(
        ownerPath: ownerPath,
        reservedFootprints: <ui.Path>[footprint],
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawPath(
        lowerPriorityClip,
        ui.Paint()
          ..color = const ui.Color(0xFFFF0000)
          ..isAntiAlias = false,
      );
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
      );
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(8, 8);
      picture.dispose();
      addTearDown(rendered.dispose);

      expect(await _alphaAt(rendered, 0, 0), greaterThan(0));
      expect(await _alphaAt(rendered, 2, 2), 0);
      expect(await _alphaAt(rendered, 3, 2), greaterThan(0));
    },
  );

  test('later cap footprint excludes an overlapping earlier cap', () {
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final undersideFootprint = ui.Path()
      ..addRect(const ui.Rect.fromLTWH(2, 3, 2, 2));
    final topFootprint = ui.Path()..addRect(const ui.Rect.fromLTWH(2, 2, 2, 2));
    final clips = terrainMaterialExclusiveCapClipPaths(
      ownerPath: ownerPath,
      orderedCapFootprints: <ui.Path>[undersideFootprint, topFootprint],
    );

    expect(clips[0].contains(const ui.Offset(2.5, 3.5)), isFalse);
    expect(clips[0].contains(const ui.Offset(2.5, 4.5)), isTrue);
    expect(clips[1].contains(const ui.Offset(2.5, 3.5)), isTrue);
  });

  test('edge footprint backs only internal repeat seams', () async {
    final source = await _sourceImageWithTransparentTopLeft();
    addTearDown(source.dispose);
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final footprint = terrainMaterialEdgeFootprintPath(
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      sourceWidth: 2,
      sourceHeight: 2,
      anchorY: 0,
      orientation: TerrainMaterialEdgeOrientation.top,
    );
    final fillClip = terrainMaterialLowerPriorityClipPath(
      ownerPath: ownerPath,
      reservedFootprints: <ui.Path>[footprint],
    );
    final edgeClip = terrainMaterialExclusiveEdgeClipPaths(
      ownerPath: ownerPath,
      orderedEdgeFootprints: <ui.Path>[footprint],
      capFootprints: const <ui.Path>[],
    ).single;
    final seamBacking = terrainMaterialEdgeSeamBackingPath(
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      sourceWidth: 2,
      sourceHeight: 2,
      anchorY: 0,
      orientation: TerrainMaterialEdgeOrientation.top,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawPath(
      fillClip,
      ui.Paint()
        ..color = const ui.Color(0xFFFF0000)
        ..isAntiAlias = false,
    );
    canvas.save();
    canvas.clipPath(edgeClip);
    canvas.clipPath(seamBacking);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      ui.Paint()
        ..color = const ui.Color(0xFFFF0000)
        ..isAntiAlias = false,
    );
    canvas.restore();
    paintTerrainMaterialEdgeImage(
      canvas,
      start: const ui.Offset(2, 2),
      length: 4,
      angle: 0,
      image: source,
      anchorY: 0,
      orientation: TerrainMaterialEdgeOrientation.top,
      clipPath: edgeClip,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(8, 8);
    picture.dispose();
    addTearDown(rendered.dispose);

    expect(await _alphaAt(rendered, 0, 0), greaterThan(0));
    expect(await _alphaAt(rendered, 2, 2), 0);
    expect(await _alphaAt(rendered, 4, 2), greaterThan(0));
    expect(await _alphaAt(rendered, 3, 2), greaterThan(0));
  });

  test('later top edge footprint excludes an overlapping wall edge', () {
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final wallFootprint = ui.Path()
      ..addRect(const ui.Rect.fromLTWH(2, 3, 2, 2));
    final topFootprint = ui.Path()..addRect(const ui.Rect.fromLTWH(2, 2, 2, 2));
    final clips = terrainMaterialExclusiveEdgeClipPaths(
      ownerPath: ownerPath,
      orderedEdgeFootprints: <ui.Path>[wallFootprint, topFootprint],
      capFootprints: const <ui.Path>[],
    );

    expect(clips[0].contains(const ui.Offset(2.5, 3.5)), isFalse);
    expect(clips[0].contains(const ui.Offset(2.5, 4.5)), isTrue);
    expect(clips[1].contains(const ui.Offset(2.5, 3.5)), isTrue);
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

Future<ui.Image> _renderEdge(
  ui.Image source, {
  required TerrainMaterialEdgeOrientation orientation,
  required ui.Offset start,
  required double length,
  required double angle,
  ui.Path? clipPath,
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
    clipPath: clipPath,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(8, 8);
  } finally {
    picture.dispose();
  }
}

Future<ui.Image> _renderCap(
  ui.Image source, {
  required ui.Offset start,
  required double length,
  required double angle,
  ui.Path? clipPath,
}) async {
  final recorder = ui.PictureRecorder();
  paintTerrainMaterialCapImage(
    ui.Canvas(recorder),
    start: start,
    length: length,
    angle: angle,
    image: source,
    anchorX: 0,
    anchorY: 0,
    atEnd: false,
    orientation: TerrainMaterialEdgeOrientation.top,
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
