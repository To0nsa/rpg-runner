import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/interactions/level_blessing.dart';
import 'package:rpg_runner/ui/hud/game/level_blessings_hud.dart';

void main() {
  testWidgets('grant feedback becomes a persistent indicator without a timer', (
    tester,
  ) async {
    Future<void> show(int tick, {bool active = true}) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LevelBlessingsHud(
            blessings: active
                ? const [
                    LevelBlessingSnapshot(
                      id: LevelBlessingId.regeneration,
                      grantedAtTick: 100,
                    ),
                  ]
                : const [],
            tick: tick,
            tickHz: 60,
          ),
        ),
      ),
    );
    await show(100);
    expect(find.text('Regeneration increased'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Regeneration increased'), findsOneWidget);
    await show(220);
    expect(find.text('Bénédiction des Dames de la forêt'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    await show(0, active: false);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });
}
