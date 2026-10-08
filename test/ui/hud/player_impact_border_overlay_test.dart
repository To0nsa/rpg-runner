import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/hud/game/player_impact_border_overlay.dart';
import 'package:rpg_runner/ui/hud/game/screen_border_vignette.dart';

void main() {
  testWidgets('each combo hit restarts the visible border pulse', (
    tester,
  ) async {
    final hits = ValueNotifier<int>(0);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PlayerImpactBorderOverlay(triggerSignal: hits),
      ),
    );
    for (var hit = 1; hit <= 4; hit++) {
      hits.value = hit;
      await tester.pump();
      expect(find.byKey(ValueKey(hit)), findsOneWidget);
      final pulse = tester.widget<ScreenBorderVignette>(
        find.byType(ScreenBorderVignette),
      );
      expect(pulse.intensity, 1);
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        tester
            .widget<ScreenBorderVignette>(find.byType(ScreenBorderVignette))
            .intensity,
        lessThan(1),
      );
    }
    await tester.pumpWidget(const SizedBox());
    hits.dispose();
  });
}
