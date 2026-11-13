import 'package:rpg_runner/ui/tutorial/campaign_tutorial_geometry.dart';
import 'package:rpg_runner/ui/viewport/viewport_metrics.dart';
import 'package:runner_core/snapshots/camera_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/controls_tuning.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/controls/widgets/movement_control.dart';
import 'package:rpg_runner/ui/controls/widgets/movement_control_placement.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:rpg_runner/ui/tutorial/campaign_tutorial_overlay.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';

void main() {
  for (final (lesson, step) in <(CampaignTutorialSequence, int)>[
    (
      CampaignWaterTutorial.introduction(
        missionChunkId: 'second',
        waterRegionId: 'pool',
      ),
      0,
    ),
    (CampaignSwimmingTutorial.introduction(), 0),
    for (var i = 0; i < 3; i++)
      (
        CampaignCombatTutorial.introduction(
          missionChunkId: 'tenth',
          markerSalt: 1,
        ),
        i,
      ),
    (CampaignMobilityTutorial.introduction(missionChunkId: 'eighth'), 0),
    for (var i = 0; i < 3; i++)
      (CampaignBlessingTutorial.introduction(shrineId: 'shrine'), i),
  ]) {
    testWidgets(
      'French ${lesson.id} step $step card fits a compact display with enlarged text',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(667, 375));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final surface = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr'),
            localizationsDelegates: RunnerLocalizations.delegates,
            supportedLocales: RunnerLocalizations.supportedLocales,
            theme: createUiTheme(),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: SizedBox.expand(
                  key: surface,
                  child: CampaignTutorialOverlay(
                    tutorial: lesson,
                    step: step,
                    onNext:
                        lesson.continuationAt(step) ==
                            CampaignTutorialContinuation.next
                        ? () {}
                        : null,
                    control: TutorialMovementControl.keyboard,
                    targetKey: null,
                    surfaceKey: surface,
                    worldTarget: lesson is CampaignWaterTutorial
                        ? () => const Rect.fromLTWH(450, 300, 100, 60)
                        : lesson.targetAt(step).isWorld
                        ? () => const Rect.fromLTWH(300, 230, 70, 70)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(lesson.titleFor('fr', step: step)), findsOneWidget);
        expect(
          find.text(
            lesson.instructionFor(
              TutorialMovementControl.keyboard,
              'fr',
              step: step,
            ),
          ),
          findsOneWidget,
        );
        if (lesson.continuationAt(step) == CampaignTutorialContinuation.next) {
          expect(find.text('Suivant').hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('obstacle projection follows camera and fitted viewport offsets', () {
    const camera = CameraSnapshot(
      centerX: 750,
      centerY: 135,
      viewWidth: 600,
      viewHeight: 270,
    );
    const obstacle = Rect.fromLTWH(615, 138, 250, 96);
    expect(
      campaignTutorialWorldTarget(
        obstacle,
        camera,
        const ViewportMetrics(
          viewW: 1200,
          viewH: 540,
          offsetX: -178,
          offsetY: -150,
        ),
      ),
      const Rect.fromLTWH(152, 126, 500, 192),
    );
    expect(
      campaignTutorialWorldTarget(
        obstacle,
        camera,
        const ViewportMetrics(
          viewW: 600,
          viewH: 270,
          offsetX: 122,
          offsetY: 60,
        ),
      ),
      const Rect.fromLTWH(287, 198, 250, 96),
    );
  });
  testWidgets(
    'three-step French cards retain reachable Next with enlarged text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(667, 375));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final tutorial = CampaignJumpTutorial.introduction(
        missionChunkId: 'mission_chunk_2',
      );
      final surface = GlobalKey();
      var step = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: RunnerLocalizations.delegates,
          supportedLocales: RunnerLocalizations.supportedLocales,
          theme: createUiTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: SizedBox.expand(
                  key: surface,
                  child: CampaignTutorialOverlay(
                    tutorial: tutorial,
                    control: TutorialMovementControl.keyboard,
                    surfaceKey: surface,
                    targetKey: null,
                    step: step,
                    onNext: step < 2 ? () => setState(() => step++) : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        expect(find.text('Suivant').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Étape 3/3'), findsOneWidget);
      expect(find.text('Surveille ton endurance'), findsOneWidget);
      expect(find.text('Suivant'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'French lesson follows the host locale and expanded text remains above movement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(667, 375));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final json = CampaignMovementTutorial.movementIntroduction().toJson();
      final instructions = Map<String, Object?>.from(
        json['instructions']! as Map,
      );
      instructions['floatingJoystick'] = {
        'en': 'Touch to move.',
        'fr': List.filled(
          8,
          'Touche la zone puis fais glisser ton doigt.',
        ).join(' '),
      };
      json['instructions'] = instructions;
      final tutorial = CampaignMovementTutorial.decode(json);
      final target = GlobalKey(), surface = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: RunnerLocalizations.delegates,
          supportedLocales: RunnerLocalizations.supportedLocales,
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: Stack(
                  key: surface,
                  fit: StackFit.expand,
                  children: [
                    MovementControlPlacement(
                      mode: MovementControlMode.joystick,
                      child: MovementControl(
                        key: target,
                        mode: MovementControlMode.joystick,
                        tuning: ControlsTuning.fixed,
                        onMoveAxis: (_) {},
                      ),
                    ),
                    CampaignTutorialOverlay(
                      tutorial: tutorial,
                      control: TutorialMovementControl.floatingJoystick,
                      targetKey: target,
                      surfaceKey: surface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Se déplacer'), findsOneWidget);
      expect(find.text('Moving around'), findsNothing);
      expect(
        tester.getRect(find.byType(Card)).bottom,
        lessThan(tester.getRect(find.byKey(target)).top),
      );
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      await tester.drag(find.byType(Card), const Offset(0, -70));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );
}
