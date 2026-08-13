import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/staged_terrain.dart';
import 'package:rpg_runner/game/themes/terrain_material_registry.dart';
import 'package:terrain_materials/terrain_materials.dart';

void main() {
  test('region extraction excludes neighboring atlas pixels', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 2, 2),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    canvas.drawRect(
      const ui.Rect.fromLTWH(2, 0, 2, 2),
      ui.Paint()..color = const ui.Color(0xFF00FF00),
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(4, 2);
    picture.dispose();
    final region = await extractTerrainRegionImage(
      source,
      const TerrainMaterialImageRegionSpec(
        assetPath: 'terrain/test.png',
        x: 2,
        y: 0,
        width: 2,
        height: 2,
      ),
    );
    addTearDown(source.dispose);
    addTearDown(region.dispose);

    expect((region.width, region.height), (2, 2));
    final bytes = await region.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(bytes, isNotNull);
    for (var offset = 0; offset < bytes!.lengthInBytes; offset += 4) {
      expect(
        <int>[
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
          bytes.getUint8(offset + 3),
        ],
        <int>[0, 255, 0, 255],
      );
    }
  });

  test('sloped edge phase uses signed tangent projection', () {
    final angle = math.pi / 4;
    final phase = terrainMaterialEdgeRepeatPhase(
      startX: 16,
      startY: 16,
      tangentX: math.cos(angle),
      tangentY: math.sin(angle),
      repeatWidth: 32,
    );

    expect(phase, closeTo(16 * math.sqrt(2), 1e-9));
  });
}
