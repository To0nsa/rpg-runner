import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkscape_runner/ui/hud/game_over_overlay.dart';

void main() {
  testWidgets('GameOverOverlay feeds collectibles into score', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          runEndedEvent: null,
          baseScore: 1000,
          collectibles: 2,
          collectibleScore: 100,
        ),
      ),
    );

    expect(find.text('Score: 1000'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 100'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.text('Score: 1100'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 0'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets('GameOverOverlay skip completes feed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameOverOverlay(
          visible: true,
          onRestart: () {},
          onExit: null,
          showExitButton: false,
          runEndedEvent: null,
          baseScore: 1000,
          collectibles: 2,
          collectibleScore: 100,
        ),
      ),
    );

    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Score: 1100'), findsOneWidget);
    expect(find.text('Collectibles: 2 -> 0'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
  });
}
