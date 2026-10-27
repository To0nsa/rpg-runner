import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/snapshots/enums.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/spatial/offscreen_indicators.dart';
import 'package:rpg_runner/game/spatial/world_view_transform.dart';
import 'package:rpg_runner/game/input/aim_preview.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/game/input/runner_semantic_action_dispatcher.dart';
import 'package:rpg_runner/ui/hud/game/game_overlay.dart';
import 'package:rpg_runner/ui/components/hud_icon_button.dart';
import 'package:rpg_runner/ui/hud/game/score_overlay.dart';
import 'package:rpg_runner/ui/hud/game/start_pause_button_overlay.dart';
import 'package:rpg_runner/ui/hud/game/survival_timer_overlay.dart';
import 'package:rpg_runner/ui/runner_game_ui_state.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:rpg_runner/ui/viewport/viewport_metrics.dart';

import '../../../../packages/runner_core/test/test_support/boss_victory_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final fonts = FontLoader('CrimsonText')
      ..addFont(
        rootBundle.load('assets/fonts/Crimson_Text/CrimsonText-Regular.ttf'),
      )
      ..addFont(
        rootBundle.load('assets/fonts/Crimson_Text/CrimsonText-Bold.ttf'),
      );
    await fonts.load();
    await (FontLoader('Cinzel')..addFont(
          rootBundle.load('assets/fonts/Cinzel/static/Cinzel-Regular.ttf'),
        ))
        .load();
    await (FontLoader('Inter')..addFont(
          rootBundle.load('assets/fonts/Inter/static/Inter_24pt-Regular.ttf'),
        ))
        .load();
  });

  for (final size in [const Size(480, 320), const Size(844, 390)]) {
    testWidgets('vitals, timer, score and boss notice stay separate at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final core = bossVictoryCore();
      advanceToBossBlessing(core);
      final controller = GameController(core: core);
      final aim = AimPreviewModel();
      final meleeAim = AimPreviewModel();
      final cancelRect = ValueNotifier<Rect?>(null);
      final cancel = ValueNotifier(0);
      final impact = ValueNotifier(0);
      final indicators = ValueNotifier<OffscreenIndicatorFrame?>(
        OffscreenIndicatorFrame(
          runId: 1,
          camera: const WorldViewTransform(
            cameraCenterX: 300,
            cameraCenterY: 135,
            viewWidth: 600,
            viewHeight: 270,
          ),
          targets: [
            for (final (id, x, y) in [
              (1, -35.0, 170.0),
              (2, -60.0, 185.0),
              (3, -120.0, 188.0),
              (4, 300.0, -50.0),
              (5, -60.0, -60.0),
            ])
              OffscreenIndicatorTarget(
                id: id,
                isPlayer: id == 1,
                body: Rect.fromCenter(
                  center: Offset(x, y),
                  width: 20,
                  height: 20,
                ),
              ),
          ],
        ),
      );
      final reviewKey = GlobalKey();
      var pauseTaps = 0;
      var exitTaps = 0;
      addTearDown(() {
        controller.dispose();
        aim.dispose();
        meleeAim.dispose();
        cancelRect.dispose();
        cancel.dispose();
        impact.dispose();
        indicators.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: reviewKey,
              child: GameOverlay(
                indicatorFrames: indicators,
                viewportMetrics: computeViewportMetrics(
                  BoxConstraints.tight(size),
                  1,
                  600,
                  270,
                  ViewportScaleMode.pixelPerfectContain,
                ),
                controller: controller,
                input: RunnerSemanticActionDispatcher(
                  input: RunnerInputRouter(controller: controller),
                  resolveInputMode: (_) => AbilityInputMode.tap,
                ),
                projectileAimPreview: aim,
                meleeAimPreview: meleeAim,
                aimCancelHitboxRect: cancelRect,
                forceAimCancelSignal: cancel,
                playerImpactFeedbackSignal: impact,
                uiState: const RunnerGameUiState(
                  started: true,
                  paused: false,
                  gameOver: false,
                  runLoaded: true,
                ),
                onStart: () {},
                onTogglePause: () => pauseTaps++,
                showExitButton: true,
                onExit: () => exitTaps++,
                exitConfirmOpen: false,
                onExitConfirmResume: () {},
                onExitConfirmExit: () {},
              ),
            ),
          ),
        ),
      );
      final vitals = tester.getRect(find.byKey(ObjectKey(controller)));
      final timer = tester.getRect(find.byType(SurvivalTimerOverlay));
      final pause = tester.getRect(find.byType(StartPauseButtonOverlay));
      final score = tester.getRect(find.byType(ScoreOverlay));
      final exit = tester.getRect(find.byType(HudIconButton).last);
      final boss = tester.getRect(
        find.text('Bénédiction des Dames de la forêt'),
      );
      expect(vitals.right, lessThan(timer.left));
      expect(timer.right, lessThan(score.left));
      expect(score.right, lessThan(pause.left));
      expect(pause.right, lessThan(exit.left));
      expect(pause.height, score.height);
      expect(exit.size, pause.size);
      expect(pause.top, score.top);
      expect(exit.top, score.top);
      expect(pause.height, greaterThanOrEqualTo(48));
      expect(timer.bottom, lessThan(boss.top));
      if (size.width < 640) {
        expect(vitals.bottom, lessThan(boss.top));
      } else {
        expect(boss.top - timer.bottom, lessThan(20));
      }
      expect(vitals.width, size.width < 600 ? 158 : 198);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            reviewKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/test/offscreen_hud_${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
      await tester.tap(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Exit game'));
      expect(pauseTaps, 1);
      expect(exitTaps, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
