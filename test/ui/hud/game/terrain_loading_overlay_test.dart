import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/ui/hud/game/terrain_loading_overlay.dart';

void main() {
  testWidgets(
    'preparing preserves mounted controls and pointer releases; failure offers recovery',
    (tester) async {
      final readiness = ValueNotifier(TerrainReadiness.ready);
      addTearDown(readiness.dispose);
      var releases = 0;
      var presses = 0;
      var retries = 0;
      var exits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: readiness,
              builder: (context, value, _) => Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    key: const ValueKey('controls'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => presses++,
                    onPointerUp: (_) => releases++,
                    child: const SizedBox.expand(),
                  ),
                  TerrainLoadingOverlay(
                    readiness: value,
                    onRetry: () => retries++,
                    onExit: () => exits++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final controls = tester.element(find.byKey(const ValueKey('controls')));
      final gesture = await tester.startGesture(const Offset(10, 10));
      readiness.value = TerrainReadiness.preparing;
      await tester.pump();
      expect(find.text('Preparing the path…'), findsOneWidget);
      expect(
        tester.element(find.byKey(const ValueKey('controls'))),
        same(controls),
      );
      await gesture.up();
      expect(releases, 1);
      await tester.tapAt(const Offset(10, 10));
      expect(presses, 2);
      readiness.value = TerrainReadiness.failed;
      await tester.pump();
      expect(
        find.text('Your run is held here. Retry to continue.'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      expect(presses, 2, reason: 'Failure blocks gameplay controls.');
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Exit'));
      expect(retries, 1);
      expect(exits, 1);
      readiness.value = TerrainReadiness.ready;
      await tester.pump();
      expect(find.text('Unable to prepare the path'), findsNothing);
    },
  );
}
