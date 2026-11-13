import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/campaign_snapshot.dart';
import 'package:rpg_runner/game/game_controller.dart';
import 'package:rpg_runner/game/input/runner_input_router.dart';
import 'package:rpg_runner/ui/campaign/campaign_hud.dart';
import 'package:rpg_runner/ui/components/hud_frame.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:rpg_runner/ui/theme/ui_tokens.dart';

void main() {
  testWidgets(
    'coin card completes, retains paused acknowledgement, fades and resets',
    (tester) async {
      Future<GameController> controller() async {
        final core = GameCore.campaignPlaytest(
          mission: campaignMissions['reporting_for_duty']!,
          playerCharacter: PlayerCharacterRegistry.eloise,
          seed: 42,
        );
        await core.prepareNextTick();
        return GameController(core: core);
      }

      final first = await controller();
      final input = RunnerInputRouter(controller: first);
      addTearDown(first.dispose);
      await tester.pumpWidget(
        _app(CampaignHud(controller: first, showBlessingObjective: false)),
      );
      expect(find.text('Collect a coin 0/1'), findsOneWidget);
      expect(find.byType(HudPanel), findsOneWidget);
      expect(find.textContaining('Objectives:'), findsNothing);
      expect(find.text('Reach the exit'), findsNothing);
      expect(find.byIcon(Icons.check), findsNothing);

      Future<void> ticks(int count) async {
        final target = first.tick + count;
        for (
          var frame = 0;
          frame < count + 10 && first.tick < target;
          frame++
        ) {
          input.pumpHeldInputs();
          first.advanceFrame(1 / 60);
          await tester.pump();
        }
        expect(first.tick, target);
      }

      input.setMoveAxis(1);
      // Finite, continuous authored spawn-to-coin traversal; no tutorial pause here.
      for (
        var budget = 0;
        budget < 300 && first.snapshot.hud.collectibles == 0;
        budget++
      ) {
        await ticks(1);
      }
      expect(first.snapshot.hud.collectibles, 1);
      final completedTick = first.tick;
      input.setMoveAxis(0);
      expect(find.text('Collect a coin 1/1'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check)).color,
        tester.element(find.byType(CampaignHud)).ui.colors.success,
      );
      expect(find.text('Reach the exit'), findsNothing);

      first.setPaused(true);
      await tester.pump(const Duration(seconds: 10));
      first.advanceFrame(.1);
      expect(first.tick, completedTick);
      expect(find.text('Collect a coin 1/1'), findsOneWidget);
      first.setPaused(false);
      await ticks(179);
      expect(find.text('Collect a coin 1/1'), findsOneWidget);
      await ticks(9);
      final fadingCard = find.ancestor(
        of: find.byType(HudPanel),
        matching: find.byType(Opacity),
      );
      expect(
        tester.widget<Opacity>(fadingCard).opacity,
        inExclusiveRange(0, 1),
      );
      await ticks(7);
      expect(find.byType(HudPanel), findsNothing);
      expect(find.textContaining('Collect a coin'), findsNothing);

      final restarted = await controller();
      addTearDown(restarted.dispose);
      await tester.pumpWidget(
        _app(CampaignHud(controller: restarted, showBlessingObjective: false)),
      );
      expect(find.text('Collect a coin 0/1'), findsOneWidget);
      first.setPaused(true);
      await tester.pump();
      expect(find.text('Collect a coin 0/1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      first.setPaused(false);
      restarted.setPaused(true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blessing disclosure and acknowledgement age independently of the coin',
    (tester) async {
      Future<void> panel({
        bool shown = true,
        bool received = false,
        Duration age = Duration.zero,
        Locale locale = const Locale('en'),
      }) => tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 220,
              child: CampaignObjectivesPanel(
                campaign: CampaignSnapshot(
                  missionId: 'blessing',
                  completed: received ? 2 : 1,
                  required: 2,
                  failed: false,
                  exitX: 600,
                  exitY: 224,
                  firstCoinRequired: true,
                  firstCoinCollected: true,
                  blessingRequired: true,
                  blessingReceived: received,
                ),
                playerX: 300,
                completedFor: const Duration(seconds: 4),
                blessingCompletedFor: age,
                showBlessingObjective: shown,
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await panel(shown: false);
      expect(find.byType(HudPanel), findsNothing);
      expect(find.textContaining('Objectives:'), findsNothing);
      await panel();
      expect(find.text('Receive a blessing 0/1'), findsOneWidget);
      expect(find.textContaining('Collect a coin'), findsNothing);
      await panel(received: true);
      expect(find.text('Receive a blessing 1/1'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('Receive a blessing 1/1'), findsOneWidget);
      await panel(received: true, age: const Duration(milliseconds: 3125));
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byType(HudPanel),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        .5,
      );
      await panel(received: true, age: const Duration(seconds: 4));
      expect(find.byType(HudPanel), findsNothing);
      await panel(received: true, locale: const Locale('fr'));
      expect(find.text('Recevoir une bénédiction 1/1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('French card fits a compact HUD at enlarged text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 220,
            child: CampaignObjectivesPanel(
              campaign: CampaignSnapshot(
                missionId: 'coin',
                completed: 1,
                required: 1,
                failed: false,
                exitX: 600,
                exitY: 224,
                firstCoinRequired: true,
                firstCoinCollected: true,
              ),
              playerX: 300,
            ),
          ),
        ),
        locale: const Locale('fr'),
      ),
    );
    expect(find.text('Ramasse une pièce 1/1'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retiring the coin does not hide other mission objectives', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const CampaignObjectivesPanel(
          campaign: CampaignSnapshot(
            missionId: 'mixed',
            completed: 1,
            required: 2,
            failed: false,
            exitX: 600,
            exitY: 224,
            firstCoinRequired: true,
            firstCoinCollected: true,
          ),
          playerX: 300,
          completedFor: Duration(seconds: 4),
        ),
      ),
    );
    expect(find.textContaining('Collect a coin'), findsNothing);
    expect(find.text('Objectives: 0/1'), findsOneWidget);
    expect(find.byType(HudPanel), findsOneWidget);
  });
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: createUiTheme(),
  locale: locale,
  localizationsDelegates: RunnerLocalizations.delegates,
  supportedLocales: RunnerLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);
