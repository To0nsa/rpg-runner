import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:rpg_runner/game/components/npcs/npc_health_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cleared guard shows a check above its live health bar', () async {
    Future<(int, int)> visiblePixels(NpcHealthSnapshot health) async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..translate(32, 24);
      final indicator = NpcHealthIndicator()..health = health;
      indicator.render(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(64, 48);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);
      final pixels = bytes!.buffer.asUint8List();

      int count(int minX, int maxX, int minY, int maxY) {
        var total = 0;
        for (var y = minY; y <= maxY; y++) {
          for (var x = minX; x <= maxX; x++) {
            if (pixels[(y * 64 + x) * 4 + 3] > 0) total++;
          }
        }
        return total;
      }

      final result = (count(25, 39, 8, 18), count(17, 24, 23, 29));
      image.dispose();
      picture.dispose();
      return result;
    }

    const fighting = NpcHealthSnapshot(
      hp100: 1500,
      maxHp100: 2000,
      protected: false,
    );
    const guarding = NpcHealthSnapshot(
      hp100: 1500,
      maxHp100: 2000,
      protected: false,
      guarding: true,
    );
    const protected = NpcHealthSnapshot(
      hp100: 1500,
      maxHp100: 2000,
      protected: true,
    );

    final (fightingCheck, fightingBar) = await visiblePixels(fighting);
    final (guardCheck, guardBar) = await visiblePixels(guarding);
    final (protectedCheck, protectedBar) = await visiblePixels(protected);
    expect(fightingCheck, 0);
    expect(fightingBar, greaterThan(0));
    expect(guardCheck, greaterThan(0));
    expect(guardBar, greaterThan(0));
    expect(protectedCheck, 0);
    expect(protectedBar, 0);
  });
}
