import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/hud/game/player_impact_border_overlay.dart';
import 'package:rpg_runner/ui/hud/game/screen_border_vignette.dart';

void main() {
  testWidgets(
    'shared border geometry keeps the center clear with red and black styles',
    (tester) async {
      tester.view.physicalSize = const ui.Size(1200, 270);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: Row(
              children: [
                for (final style in ScreenBorderVignetteStyle.values)
                  Expanded(
                    child: ColoredBox(
                      color: const Color(0xFF808080),
                      child: ScreenBorderVignette(style: style, intensity: 1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        addTearDown(image.dispose);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        List<int> rgb(int x, int y) => pixels.sublist(
          (y * image.width + x) * 4,
          (y * image.width + x) * 4 + 3,
        );
        expect(rgb(300, 135), [128, 128, 128]);
        expect(rgb(900, 135), [128, 128, 128]);
        final red = rgb(10, 135), black = rgb(610, 135);
        expect(red[0], greaterThan(red[1]));
        expect(black[0], lessThan(128));
        expect(black, [black[0], black[0], black[0]]);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/test/boss_entrance_border_review.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(Uint8List.view(png!.buffer));
      });
    },
  );
  testWidgets(
    'player impact keeps its red 340 ms fade and border never intercepts taps',
    (tester) async {
      final trigger = ValueNotifier(0);
      addTearDown(trigger.dispose);
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox.expand(),
              ),
              PlayerImpactBorderOverlay(triggerSignal: trigger),
            ],
          ),
        ),
      );
      trigger.value = 1;
      await tester.pump();
      expect(
        tester
            .widget<ScreenBorderVignette>(find.byType(ScreenBorderVignette))
            .style,
        ScreenBorderVignetteStyle.playerImpact,
      );
      await tester.tapAt(const Offset(5, 5));
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.byType(ScreenBorderVignette), findsNothing);
    },
  );
}
