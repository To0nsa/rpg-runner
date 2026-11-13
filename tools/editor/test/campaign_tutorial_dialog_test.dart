import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:rpg_runner/ui/hud/game/level_blessings_hud.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_steps_tutorial_dialog.dart';
import 'package:rpg_runner/ui/controls/widgets/jump_control.dart';
import 'package:rpg_runner/ui/controls/widgets/tap_ability_control.dart';
import 'package:rpg_runner/ui/controls/action_button.dart';
import 'package:rpg_runner/ui/hud/game/resource_bars_panel.dart';
import 'package:rpg_runner/ui/campaign/campaign_hud.dart';
import 'package:flutter/material.dart';
import 'package:rpg_runner/ui/hud/game/score_overlay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/move_buttons.dart';
import 'package:rpg_runner/ui/controls/movement_control_mode.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_core/campaign/campaign_mission_definition.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_tutorial_sequences.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_tutorial_spotlight_canvas.dart';

void main() {
  testWidgets(
    'combat authors marker, bilingual practice hint and all attack pages',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = CampaignCombatTutorial.introduction(
        missionChunkId: 'tenth',
        markerSalt: 1,
      );
      CampaignCombatTutorial? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Edit'),
                onPressed: () async {
                  result = await showDialog<CampaignCombatTutorial>(
                    context: context,
                    builder: (_) => CampaignStepsTutorialDialog(
                      tutorial: original,
                      missionChunkIds: const ['tenth'],
                      enemies: [
                        CampaignEnemySource(
                          'enemy',
                          CampaignPoint(
                            missionChunkId: 'tenth',
                            x: 312,
                            y: 184,
                          ),
                          marker: SpawnMarker(
                            enemyId: EnemyId.grojib,
                            x: 312,
                            chancePercent: 100,
                            salt: 1,
                          ),
                          required: false,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Enemy marker'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Sequence name'),
        'Combat lesson',
      );
      final step = find.text('2. Projectile');
      await tester.ensureVisible(step);
      await tester.tap(step);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Instruction (en)'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Instruction (en)'),
        'Press Projectile to fire once.',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.name, 'Combat lesson');
      expect(result!.markerSalt, 1);
      expect(
        result!.instructionFor(TutorialMovementControl.arrows, 'en', step: 1),
        'Press Projectile to fire once.',
      );
      expect(result!.practiceHint['fr'], original.practiceHint['fr']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dash authors trigger and control spotlight with atomic cancel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original = CampaignMobilityTutorial.introduction(
      missionChunkId: 'eighth',
    );
    CampaignMobilityTutorial? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: createUiTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<CampaignMobilityTutorial>(
                  context: context,
                  builder: (_) => CampaignTutorialDialog(
                    tutorial: original,
                    missionChunkIds: const ['eighth', 'ninth'],
                  ),
                );
              },
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final x = find.widgetWithText(TextFormField, 'Trigger X (world units)');
    await tester.enterText(x, '601');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a position from 0 to 600.'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(x, '510');
    final instruction = find.widgetWithText(TextFormField, 'Instruction (en)');
    await tester.ensureVisible(instruction);
    await tester.enterText(instruction, 'Press Mobility to dash.');
    final control = find.byType(TapAbilityControl);
    expect(control, findsOneWidget);
    final canvas = find.byType(CampaignTutorialSpotlightCanvas);
    await tester.ensureVisible(canvas);
    await tester.pumpAndSettle();
    final target = find.descendant(
      of: control,
      matching: find.byType(ActionButton),
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.dragFrom(tester.getCenter(target), const Offset(-8, -8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result!.triggerX, 510);
    expect(result!.instruction['en'], 'Press Mobility to dash.');
    expect(result!.instruction['fr'], original.instruction['fr']);
    expect(result!.spotlight.x, isNot(original.spotlight.x));
    expect(result!.reveals, {TutorialHudElement.mobility});
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(x, '250');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(original.triggerX, 522);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an oversized opening remains movable and can be redrawn', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var spotlight = const TutorialSpotlight(x: -1, y: -1, width: 4, height: 4);
    await tester.pumpWidget(
      MaterialApp(
        theme: createUiTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CampaignTutorialSpotlightCanvas(
              mode: MovementControlMode.joystick,
              spotlight: spotlight,
              onChanged: (value) => setState(() => spotlight = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final canvas = find.byKey(const ValueKey('tutorial_spotlight_canvas'));
    final bounds = tester.getRect(canvas);
    await tester.dragFrom(bounds.center, const Offset(28, 16));
    await tester.pumpAndSettle();
    expect(spotlight.x, greaterThan(-1));
    expect(spotlight.y, greaterThan(-1));
    expect(spotlight.width, 4);
    expect(spotlight.height, 4);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Draw spotlight'));
    await tester.pumpAndSettle();
    await tester.dragFrom(
      Offset(
        bounds.left + bounds.width * .05,
        bounds.top + bounds.height * .65,
      ),
      Offset(bounds.width * .2, bounds.height * .25),
    );
    await tester.pumpAndSettle();
    expect(spotlight.width, closeTo(.2 / .33, .02));
    expect(spotlight.height, closeTo(.5, .02));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'movement lesson edits translations and anchored spotlight, Cancel discards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = CampaignMovementTutorial.movementIntroduction();
      CampaignMovementTutorial? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<CampaignMovementTutorial>(
                    context: context,
                    builder: (_) => CampaignTutorialDialog(tutorial: original),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(MoveButtons), findsOneWidget);
      final canvas = find.byKey(const ValueKey('tutorial_spotlight_canvas'));
      await tester.ensureVisible(canvas);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byType(MoveButtons));
      await tester.dragFrom(bounds.center, const Offset(24, -16));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(
        result!.spotlights[TutorialMovementControl.arrows]!.x,
        isNot(original.spotlights[TutorialMovementControl.arrows]!.x),
      );
      expect(result!.instructions, original.instructions);
      result = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coin lesson authors text, reveals and the real counters spotlight',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = CampaignCoinTutorial.introduction();
      CampaignCoinTutorial? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<CampaignCoinTutorial>(
                    context: context,
                    builder: (_) => CampaignTutorialDialog(tutorial: original),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(MoveButtons), findsNothing);
      expect(find.byType(RunStatsPanel), findsOneWidget);
      await tester.ensureVisible(find.text('Reveal and keep visible'));
      await tester.tap(find.text('Reveal and keep visible'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Jump'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Jump'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reveal and keep visible'));
      await tester.tap(find.text('Reveal and keep visible'));
      await tester.pumpAndSettle();
      final instruction = find.widgetWithText(
        TextFormField,
        'Instruction (en)',
      );
      await tester.ensureVisible(instruction);
      await tester.enterText(instruction, 'A collected coin gives 1 gold.');
      final panel = find.byType(RunStatsPanel);
      await tester.ensureVisible(panel);
      await tester.pumpAndSettle();
      await tester.dragFrom(tester.getCenter(panel), const Offset(-12, 12));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.instruction['en'], 'A collected coin gives 1 gold.');
      expect(result!.instruction['fr'], original.instruction['fr']);
      expect(result!.reveals, {
        TutorialHudElement.runStats,
        TutorialHudElement.jump,
      });
      expect(result!.spotlight.x, isNot(original.spotlight.x));
      expect(original.reveals, {TutorialHudElement.runStats});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'objectives lesson authors text, reveals and the real objectives spotlight',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = CampaignObjectivesTutorial.introduction();
      CampaignObjectivesTutorial? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<CampaignObjectivesTutorial>(
                    context: context,
                    builder: (_) => CampaignTutorialDialog(tutorial: original),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(MoveButtons), findsNothing);
      expect(find.byType(CampaignObjectivesPanel), findsOneWidget);
      await tester.ensureVisible(find.text('Reveal and keep visible'));
      await tester.tap(find.text('Reveal and keep visible'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Jump'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Jump'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reveal and keep visible'));
      await tester.tap(find.text('Reveal and keep visible'));
      await tester.pumpAndSettle();
      final instruction = find.widgetWithText(
        TextFormField,
        'Instruction (en)',
      );
      await tester.ensureVisible(instruction);
      await tester.enterText(
        instruction,
        'Collect a coin to finish your first objective.',
      );
      final panel = find.byType(CampaignObjectivesPanel);
      await tester.ensureVisible(panel);
      await tester.pumpAndSettle();
      await tester.dragFrom(tester.getCenter(panel), const Offset(-12, 12));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        result!.instruction['en'],
        'Collect a coin to finish your first objective.',
      );
      expect(result!.instruction['fr'], original.instruction['fr']);
      expect(result!.reveals, {
        TutorialHudElement.objectives,
        TutorialHudElement.jump,
      });
      expect(result!.spotlight.x, isNot(original.spotlight.x));
      expect(original.reveals, {TutorialHudElement.objectives});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid hidden translation is revealed and blocks Apply', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: createUiTheme(),
        home: Scaffold(
          body: CampaignTutorialDialog(
            tutorial: CampaignMovementTutorial.movementIntroduction(),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Français').last);
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instruction (fr)'),
      '',
    );
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.byType(CampaignTutorialDialog), findsOneWidget);
    expect(find.text('Required.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'three-step jump sequence edits all pages atomically and rejects hidden errors',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = CampaignJumpTutorial.introduction(
        missionChunkId: 'mission_chunk_2',
      );
      CampaignJumpTutorial? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<CampaignJumpTutorial>(
                    context: context,
                    builder: (_) => CampaignStepsTutorialDialog(
                      tutorial: original,
                      missionChunkIds: const [
                        'mission_chunk_1',
                        'mission_chunk_2',
                      ],
                    ),
                  );
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      Future<void> page(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      final title = find.widgetWithText(TextFormField, 'Card title (en)');
      await tester.ensureVisible(title);
      await tester.enterText(title, 'A rock blocks your path');
      final width = find.widgetWithText(TextFormField, 'Target width');
      await tester.ensureVisible(width);
      await tester.enterText(width, 'NaN');
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Invalid drafts must not break preview painting.',
      );
      await tester.enterText(width, '250');
      await page('2. Jump');
      expect(find.byType(JumpControl), findsOneWidget);
      final jump = find.byType(JumpControl);
      await tester.ensureVisible(jump);
      await tester.pumpAndSettle();
      await tester.dragFrom(tester.getCenter(jump), const Offset(-12, -8));
      await tester.pumpAndSettle();
      await page('3. Resources');
      expect(find.byType(ResourceBarsPanel), findsOneWidget);
      await tester.ensureVisible(find.text('Français').last);
      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();
      final french = find.widgetWithText(TextFormField, 'Instruction (fr)');
      await tester.ensureVisible(french);
      await tester.enterText(french, '');
      await page('1. Obstacle');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(ResourceBarsPanel), findsOneWidget);
      expect(find.text('Required.'), findsOneWidget);
      await tester.ensureVisible(french);
      await tester.enterText(french, 'Sauter consomme de l’endurance.');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.missionChunkId, 'mission_chunk_2');
      expect(result!.steps[0].title['en'], 'A rock blocks your path');
      expect(
        result!.steps[1].spotlight.x,
        isNot(original.steps[1].spotlight.x),
      );
      expect(
        result!.steps[2].instruction['fr'],
        'Sauter consomme de l’endurance.',
      );
      expect(result!.steps[2].reveals, {TutorialHudElement.resources});
      expect(original.steps[0].title['en'], 'Obstacles ahead');
      result = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'blessing pages share editing, validate hidden translations and cancel atomically',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final original = CampaignBlessingTutorial.introduction(
        shrineId: 'shrine',
      );
      final shrine = original.resolveShrine(
        campaignMissions['reporting_for_duty']!,
      );
      CampaignBlessingTutorial? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: createUiTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Edit'),
                onPressed: () async {
                  result = await showDialog<CampaignBlessingTutorial>(
                    context: context,
                    builder: (_) => CampaignStepsTutorialDialog(
                      tutorial: original,
                      missionChunkIds: const ['mission_chunk_7'],
                      shrines: [shrine],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      Future<void> page(String title) async {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }

      final distance = find.widgetWithText(
        TextFormField,
        'Approach distance before shrine (world units)',
      );
      await tester.ensureVisible(distance);
      await tester.enterText(distance, '80');
      await page('2. Blessing');
      final title = find.widgetWithText(TextFormField, 'Card title (en)');
      await tester.ensureVisible(title);
      await tester.enterText(title, 'The fire is lit');
      await page('3. Regeneration');
      expect(find.byType(ResourceBarsPanel), findsOneWidget);
      expect(find.byType(LevelBlessingsHud), findsOneWidget);
      await tester.ensureVisible(find.byType(LevelBlessingsHud));
      await tester.pumpAndSettle();
      await tester.dragFrom(
        tester.getCenter(find.byType(LevelBlessingsHud)),
        const Offset(12, -8),
      );
      await tester.ensureVisible(find.text('Français').last);
      await tester.tap(find.text('Français').last);
      await tester.pumpAndSettle();
      final french = find.widgetWithText(TextFormField, 'Instruction (fr)');
      await tester.ensureVisible(french);
      await tester.enterText(french, '');
      await page('1. Objective');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Required.'), findsOneWidget);
      await tester.ensureVisible(french);
      await tester.enterText(
        french,
        'La bénédiction améliore la régénération.',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.shrineId, 'shrine');
      expect(result!.approachDistance, 80);
      expect(result!.steps[1].title['en'], 'The fire is lit');
      expect(
        result!.steps[2].spotlight.x,
        isNot(original.steps[2].spotlight.x),
      );
      expect(
        result!.steps[2].instruction['fr'],
        'La bénédiction améliore la régénération.',
      );
      expect(original.approachDistance, 96);
      result = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignStepsTutorialDialog(
            tutorial: original,
            missionChunkIds: const [],
          ),
        ),
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Select an available shrine marker.'), findsOneWidget);
    },
  );
}
