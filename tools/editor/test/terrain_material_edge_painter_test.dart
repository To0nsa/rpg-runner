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
    const region = TerrainMaterialImageRegion(
      assetPath: 'assets/images/terrain/test/atlas.png',
      x: 0,
      y: 0,
      width: 2,
      height: 3,
    );
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
        region: region,
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
    const region = TerrainMaterialImageRegion(
      assetPath: 'assets/images/terrain/test/atlas.png',
      x: 0,
      y: 0,
      width: 2,
      height: 3,
    );
    final recorder = ui.PictureRecorder();
    paintTerrainMaterialCapRegion(
      ui.Canvas(recorder),
      image: source,
      region: region,
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

  test('polygon clip contains edge bands and caps at sloped corners', () async {
    final source = await _sourceImage();
    addTearDown(source.dispose);
    const region = TerrainMaterialImageRegion(
      assetPath: 'assets/images/terrain/test/atlas.png',
      x: 0,
      y: 0,
      width: 2,
      height: 3,
    );
    final ownerPath = ui.Path()
      ..moveTo(2, 2)
      ..lineTo(6, 2)
      ..lineTo(6, 5)
      ..lineTo(4, 5)
      ..close();
    final unclippedEdge = await _renderEdge(
      source,
      region: region,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
    );
    final clippedEdge = await _renderEdge(
      source,
      region: region,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
      clipPath: ownerPath,
    );
    final clippedCap = await _renderCap(
      source,
      region: region,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
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
    const region = TerrainMaterialImageRegion(
      assetPath: 'assets/images/terrain/test/atlas.png',
      x: 0,
      y: 0,
      width: 2,
      height: 3,
    );
    final rendered = await _renderEdge(
      source,
      region: region,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(4, 2),
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
      const region = TerrainMaterialImageRegion(
        assetPath: 'assets/images/terrain/test/atlas.png',
        x: 0,
        y: 0,
        width: 2,
        height: 2,
      );
      final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
      final footprint = terrainMaterialCapFootprintPath(
        region: region,
        orientation: TerrainMaterialEdgeOrientation.top,
        start: const ui.Offset(2, 2),
        end: const ui.Offset(6, 2),
        anchorX: 0,
        anchorY: 0,
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
      paintTerrainMaterialCapRegion(
        canvas,
        image: source,
        region: region,
        orientation: TerrainMaterialEdgeOrientation.top,
        start: const ui.Offset(2, 2),
        end: const ui.Offset(6, 2),
        anchorX: 0,
        anchorY: 0,
        atEnd: false,
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
    const region = TerrainMaterialImageRegion(
      assetPath: 'assets/images/terrain/test/atlas.png',
      x: 0,
      y: 0,
      width: 2,
      height: 2,
    );
    final ownerPath = ui.Path()..addRect(const ui.Rect.fromLTWH(0, 0, 8, 8));
    final footprint = terrainMaterialEdgeFootprintPath(
      region: region,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
      anchorY: 0,
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
      region: region,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
      anchorY: 0,
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
    paintTerrainMaterialEdgeRegion(
      canvas,
      image: source,
      region: region,
      orientation: TerrainMaterialEdgeOrientation.top,
      start: const ui.Offset(2, 2),
      end: const ui.Offset(6, 2),
      anchorY: 0,
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
  required TerrainMaterialImageRegion region,
  required TerrainMaterialEdgeOrientation orientation,
  required ui.Offset start,
  required ui.Offset end,
  ui.Path? clipPath,
}) async {
  final recorder = ui.PictureRecorder();
  paintTerrainMaterialEdgeRegion(
    ui.Canvas(recorder),
    image: source,
    region: region,
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

Future<ui.Image> _renderCap(
  ui.Image source, {
  required TerrainMaterialImageRegion region,
  required ui.Offset start,
  required ui.Offset end,
  ui.Path? clipPath,
}) async {
  final recorder = ui.PictureRecorder();
  paintTerrainMaterialCapRegion(
    ui.Canvas(recorder),
    image: source,
    region: region,
    orientation: TerrainMaterialEdgeOrientation.top,
    start: start,
    end: end,
    anchorX: 0,
    anchorY: 0,
    atEnd: false,
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
