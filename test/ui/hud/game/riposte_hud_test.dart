import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/hud/game/riposte_hud.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';

void main() {
  testWidgets(
    'riposte shows held reward, release countdown and expiry from Core',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 320));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> show(int ticks, bool guarding) => tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Center(
              child: RiposteHud(
                ticksLeft: ticks,
                guarding: guarding,
                tickHz: 60,
              ),
            ),
          ),
        ),
      );
      await show(60, true);
      expect(find.text('Riposte ready · release to counter'), findsOneWidget);
      await show(30, false);
      expect(find.text('Riposte · 0.5s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.text('Riposte · 0.5s'),
        findsOneWidget,
        reason: 'Paused/UI time must not expire an authoritative reward',
      );
      await show(0, false);
      expect(find.textContaining('Riposte'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
