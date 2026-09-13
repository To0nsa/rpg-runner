import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/components/staged_terrain.dart';
import 'package:rpg_runner/game/components/water_material_painter.dart';
import 'package:rpg_runner/game/themes/terrain_material_registry.dart';

void main() {
  test(
    'real atlas animates, tiles across pools, and leaves actors readable',
    () async {
      final material = TerrainMaterialRegistry.require('biome_water');
      final codec = await ui.instantiateImageCodec(
        await File(
          'assets/images/level/atlases/fantasy_environment/mixed_biomes.png',
        ).readAsBytes(),
      );
      final atlas = (await codec.getNextFrame()).image;
      codec.dispose();
      addTearDown(atlas.dispose);
      final images = <TerrainMaterialImageRegionSpec, ui.Image>{};
      for (final region in material.regions) {
        final image = await extractTerrainRegionImage(atlas, region);
        images[region] = image;
        addTearDown(image.dispose);
      }
      final fill = ui.Paint()
        ..shader = ui.ImageShader(
          images[material.fill]!,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList([
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
            0,
            0,
            0,
            0,
            1,
          ]),
        );
      Future<ui.Image> render({int tick = 0, bool split = false}) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawPaint(ui.Paint()..color = const ui.Color(0xFF152B3D));
        final pools = split
            ? [
                const ui.Rect.fromLTRB(64, 100, 153, 200),
                const ui.Rect.fromLTRB(153, 100, 352, 200),
              ]
            : [const ui.Rect.fromLTRB(64, 100, 352, 200)];
        void water(bool foreground) {
          for (final bounds in pools) {
            paintWaterMaterial(
              canvas,
              bounds: bounds,
              fillPaint: fill,
              surfaceImage: images[material.top.base.regionAtTick(tick, 60)]!,
              anchorY: material.top.base.anchorY,
              foreground: foreground,
            );
          }
        }

        water(false);
        canvas.drawRect(
          const ui.Rect.fromLTWH(174, 82, 20, 48),
          ui.Paint()..color = const ui.Color(0xFFF5E6BE),
        );
        water(true);
        final picture = recorder.endRecording();
        final image = await picture.toImage(416, 240);
        picture.dispose();
        return image;
      }

      final first = await render();
      final next = await render(tick: 10);
      final split = await render(split: true);
      addTearDown(first.dispose);
      addTearDown(next.dispose);
      addTearDown(split.dispose);
      final pixels = (await first.toByteData())!.buffer.asUint8List();
      expect(
        (await next.toByteData())!.buffer.asUint8List(),
        isNot(orderedEquals(pixels)),
      );
      expect(
        (await split.toByteData())!.buffer.asUint8List(),
        orderedEquals(pixels),
        reason: 'Internal pool boundaries must not restart texture phase.',
      );
      List<int> pixel(int x, int y) =>
          pixels.sublist((y * 416 + x) * 4, (y * 416 + x) * 4 + 4);
      expect(pixel(180, 90), [245, 230, 190, 255]);
      expect(
        pixel(180, 125)[0],
        greaterThan(150),
        reason: 'Submerged actor remains legible.',
      );
      expect(pixel(20, 125), [
        21,
        43,
        61,
        255,
      ], reason: 'Water is clipped to its authored rectangle.');
      final output = File('build/water_preview.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(
        (await first.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
    },
  );
}
