import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rpg_runner/ui/assets/ui_asset_lifecycle.dart';
import 'package:rpg_runner/ui/components/player_idle_preview.dart';
import 'package:runner_core/players/player_character_definition.dart';

void main() {
  for (final size in [88.0, 120.0]) {
    testWidgets('menu previews share height and foot baseline at $size', (
      tester,
    ) async {
      final assets = UiAssetLifecycle();
      addTearDown(assets.dispose);
      final keys = [GlobalKey(), GlobalKey()];
      const characters = [
        PlayerCharacterId.eloise,
        PlayerCharacterId.bountyHunter,
      ];
      await tester.runAsync(() async {
        for (final id in characters) {
          await assets.getIdle(id);
        }
      });
      await tester.pumpWidget(
        Provider<UiAssetLifecycle>.value(
          value: assets,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < characters.length; i++)
                    RepaintBoundary(
                      key: keys[i],
                      child: PlayerIdlePreview(
                        characterId: characters[i],
                        size: size,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final bounds = <(int, int)>[];
      await tester.runAsync(() async {
        for (var i = 0; i < keys.length; i++) {
          final image =
              await (keys[i].currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 3);
          final rgba = (await image.toByteData())!;
          var top = image.height, bottom = -1;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              if (rgba.getUint8((y * image.width + x) * 4 + 3) < 192) continue;
              // Held equipment may rise above the head; compare body heights.
              if ((x - image.width / 2).abs() <= 3 && y < top) top = y;
              if (y > bottom) bottom = y;
            }
          }
          bounds.add((top, bottom));
          if (Platform.environment['WILLOW_SCALE_CAPTURE'] == 'true') {
            final png = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '.tmp/willow_scale_preview_${characters[i].name}_${size.toInt()}.png',
            ).writeAsBytes(png.buffer.asUint8List());
          }
          image.dispose();
        }
      });
      expect(bounds[1].$2, closeTo(bounds[0].$2, 1));
      expect(
        bounds[1].$2 - bounds[1].$1,
        closeTo(bounds[0].$2 - bounds[0].$1, 3),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
