import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_runner/ui/controls/widgets/jump_control.dart';
import 'package:rpg_runner/ui/theme/ui_theme.dart';
import 'package:runner_content_pipeline/campaign_tutorial.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_core/campaign/campaign_registry.dart';
import 'package:runner_core/track/chunk_pattern.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_tutorial_dialog.dart';
import 'package:runner_editor/src/app/pages/campaign/campaign_tutorial_spotlight_canvas.dart';

void main() {
  final water = WaterRegionData(
    id: 'pool',
    x: 300,
    y: 224,
    width: 96,
    height: 46,
    materialKey: 'biome_water',
  );
  final introduction = CampaignWaterTutorial.introduction(
    missionChunkId: 'second',
    waterRegionId: water.id,
  );

  Future<void> mount(
    WidgetTester tester,
    CampaignTutorialSequence lesson,
    ValueChanged<CampaignTutorialSequence?> onResult, {
    bool missingWater = false,
    bool missingGap = false,
    bool missingPlatform = false,
    List<ChunkVisualSpriteRel> decorations = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: createUiTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showDialog<CampaignTutorialSequence>(
                  context: context,
                  builder: (_) => CampaignTutorialDialog(
                    tutorial: lesson,
                    platformsByChunk: {
                      'fourth': [
                        if (!missingPlatform)
                          ...campaignTutorialPlatforms(
                            campaignMissions['reporting_for_duty']!
                                .terrainCatalog
                                .requireChunk('forest_default_early_cmp_005'),
                            campaignMissions['reporting_for_duty']!
                                .route
                                .missionChunks[3]
                                .pattern
                                .visualSprites,
                          ),
                      ],
                    },
                    gapsByChunk: {
                      'third': [
                        if (!missingGap)
                          ...campaignTutorialGaps(
                            campaignMissions['reporting_for_duty']!
                                .terrainCatalog
                                .requireChunk('forest_default_early_cmp_004'),
                          ),
                      ],
                    },
                    waterRegionsByChunk: {
                      'second': [if (!missingWater) water],
                    },
                    spritesByChunk: {'second': decorations},
                    worldPreviewBuilder: (_) =>
                        const ColoredBox(color: Colors.blueGrey),
                  ),
                ),
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  final platform = CampaignPlatformTutorial.introduction(
    missionChunkId: 'fourth',
    platformPrefabKey: 'tiny_swords_ground_platform_04_64x32_platform',
  );
  testWidgets('platform edits distance, languages and manual spotlight', (
    tester,
  ) async {
    CampaignTutorialSequence? result;
    await mount(tester, platform, (value) => result = value);
    final distance = find.widgetWithText(
      TextFormField,
      'Approach distance before platform (world units)',
    );
    await tester.ensureVisible(distance);
    await tester.enterText(distance, '80');
    final instruction = find.widgetWithText(TextFormField, 'Instruction (en)');
    await tester.ensureVisible(instruction);
    await tester.enterText(instruction, 'Jump up through this platform.');
    final canvas = find.byKey(const ValueKey('tutorial_spotlight_canvas'));
    await tester.ensureVisible(canvas);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    final preview = tester.widget<CampaignTutorialSpotlightCanvas>(
      find.byType(CampaignTutorialSpotlightCanvas),
    );
    expect(preview.worldTarget, const Rect.fromLTWH(160, 160, 64, 32));
    final bounds = Rect.fromPoints(
      tester.getTopLeft(canvas),
      tester.getBottomRight(canvas),
    );
    final scale = math.min(bounds.width / 600, bounds.height / 270);
    final origin = bounds.center - Offset(300 * scale, 135 * scale);
    await tester.dragFrom(
      origin + Offset(192 * scale, 176 * scale),
      const Offset(18, -10),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final authored = result! as CampaignPlatformTutorial;
    expect(authored.approachDistance, 80);
    expect(authored.instruction['en'], 'Jump up through this platform.');
    expect(authored.instruction['fr'], platform.instruction['fr']);
    expect(authored.platformPrefabKey, platform.platformPrefabKey);
    expect(authored.spotlight.x, isNot(platform.spotlight.x));
    expect(authored.reveals, isEmpty);
    result = null;
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('platform refuses an unavailable or ambiguous target', (
    tester,
  ) async {
    CampaignTutorialSequence? result;
    await mount(
      tester,
      platform,
      (value) => result = value,
      missingPlatform: true,
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Select platform from this chunk.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  final gap = CampaignGapTutorial.introduction(
    missionChunkId: 'third',
    nearGroundShapeId: 'ground_001',
    farGroundShapeId: 'solid_002',
  );
  testWidgets(
    'gap edits distance, bilingual card and manual terrain spotlight',
    (tester) async {
      CampaignTutorialSequence? result;
      await mount(tester, gap, (value) => result = value);
      final distance = find.widgetWithText(
        TextFormField,
        'Approach distance before gap (world units)',
      );
      await tester.ensureVisible(distance);
      await tester.enterText(distance, '0');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Enter a distance from 1 to 600.'), findsOneWidget);
      await tester.enterText(distance, '100');
      final instruction = find.widgetWithText(
        TextFormField,
        'Instruction (en)',
      );
      await tester.ensureVisible(instruction);
      await tester.enterText(instruction, 'Jump over the opening.');
      final canvas = find.byKey(const ValueKey('tutorial_spotlight_canvas'));
      await tester.ensureVisible(canvas);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<CampaignTutorialSpotlightCanvas>(
        find.byType(CampaignTutorialSpotlightCanvas),
      );
      expect(preview.target, CampaignTutorialTarget.gap);
      expect(preview.worldTarget, const Rect.fromLTWH(221, 200, 69, 72));
      final bounds = Rect.fromPoints(
        tester.getTopLeft(canvas),
        tester.getBottomRight(canvas),
      );
      final scale = math.min(bounds.width / 600, bounds.height / 270);
      final origin = bounds.center - Offset(300 * scale, 135 * scale);
      await tester.dragFrom(
        origin + Offset(255 * scale, 236 * scale),
        const Offset(20, -10),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final authored = result! as CampaignGapTutorial;
      expect(authored.approachDistance, 100);
      expect(authored.instruction['en'], 'Jump over the opening.');
      expect(authored.instruction['fr'], gap.instruction['fr']);
      expect(authored.nearGroundShapeId, 'ground_001');
      expect(authored.farGroundShapeId, 'solid_002');
      expect(authored.spotlight.x, isNot(gap.spotlight.x));
      expect(authored.reveals, isEmpty);
      result = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('gap refuses a missing or no-longer-dry target', (tester) async {
    CampaignTutorialSequence? result;
    await mount(tester, gap, (value) => result = value, missingGap: true);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Select gap banks from this chunk.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  const tree = ChunkVisualSpriteRel(
    prefabKey: 'tree',
    assetPath: 'tree.png',
    srcX: 0,
    srcY: 0,
    srcWidth: 224,
    srcHeight: 160,
    x: 372,
    y: 82,
    width: 224,
    height: 160,
    isDecoration: true,
  );
  final decoration = CampaignDecorationTutorial.introduction(
    missionChunkId: 'second',
    waterRegionId: water.id,
    decorationPrefabKey: 'tree',
  );
  testWidgets(
    'decoration edits bilingual text and manual spotlight without changing its target',
    (tester) async {
      CampaignTutorialSequence? result;
      await mount(
        tester,
        decoration,
        (value) => result = value,
        decorations: [tree],
      );
      expect(find.text('Decoration to highlight'), findsOneWidget);
      expect(
        find.text('Approach distance before water (world units)'),
        findsNothing,
      );
      final instruction = find.widgetWithText(
        TextFormField,
        'Instruction (en)',
      );
      await tester.ensureVisible(instruction);
      await tester.enterText(instruction, 'Walk through the pale tree.');
      final canvas = find.byKey(const ValueKey('tutorial_spotlight_canvas'));
      await tester.ensureVisible(canvas);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<CampaignTutorialSpotlightCanvas>(
        find.byType(CampaignTutorialSpotlightCanvas),
      );
      expect(preview.target, CampaignTutorialTarget.decoration);
      expect(preview.worldTarget, const Rect.fromLTWH(372, 82, 224, 160));
      final bounds = Rect.fromPoints(
        tester.getTopLeft(canvas),
        tester.getBottomRight(canvas),
      );
      final scale = math.min(bounds.width / 600, bounds.height / 270);
      final origin = bounds.center - Offset(300 * scale, 135 * scale);
      await tester.dragFrom(
        origin + Offset(484 * scale, 162 * scale),
        const Offset(-22, -10),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final authored = result! as CampaignDecorationTutorial;
      expect(authored.instruction['en'], 'Walk through the pale tree.');
      expect(authored.instruction['fr'], decoration.instruction['fr']);
      expect(authored.spotlight.x, isNot(decoration.spotlight.x));
      expect(authored.decorationPrefabKey, 'tree');
      expect(authored.waterRegionId, water.id);
      expect(authored.reveals, isEmpty);
      result = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  for (final ambiguous in [false, true]) {
    testWidgets('decoration refuses missing/ambiguous target: $ambiguous', (
      tester,
    ) async {
      CampaignTutorialSequence? result;
      await mount(
        tester,
        decoration,
        (value) => result = value,
        decorations: ambiguous ? [tree, tree] : [],
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text('Choose an existing, unambiguous decoration.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'water panel edits approach, text and manual world spotlight atomically',
    (tester) async {
      CampaignTutorialSequence? result;
      await mount(tester, introduction, (value) => result = value);
      final distance = find.widgetWithText(
        TextFormField,
        'Approach distance before water (world units)',
      );
      await tester.enterText(distance, '0');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Enter a distance from 1 to 600.'), findsOneWidget);
      await tester.enterText(distance, '32');
      final instruction = find.widgetWithText(
        TextFormField,
        'Instruction (en)',
      );
      await tester.ensureVisible(instruction);
      await tester.enterText(instruction, 'Water slows your movement.');
      final canvas = find.byKey(const ValueKey('tutorial_spotlight_canvas'));
      await tester.ensureVisible(canvas);
      await tester.pumpAndSettle();
      // The pool lies at the bottom of the preview; scroll it above the fixed
      // dialog actions before dragging rather than hitting through that footer.
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final preview = tester.widget<CampaignTutorialSpotlightCanvas>(
        find.byType(CampaignTutorialSpotlightCanvas),
      );
      expect(preview.target, CampaignTutorialTarget.water);
      expect(preview.worldTarget, const Rect.fromLTWH(300, 224, 96, 46));
      final bounds = Rect.fromPoints(
        tester.getTopLeft(canvas),
        tester.getBottomRight(canvas),
      );
      final scale = math.min(bounds.width / 600, bounds.height / 270);
      final origin = bounds.center - Offset(300 * scale, 135 * scale);
      await tester.dragFrom(
        origin + Offset(348 * scale, 247 * scale),
        const Offset(24, -12),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final authored = result! as CampaignWaterTutorial;
      expect(authored.missionChunkId, 'second');
      expect(authored.waterRegionId, 'pool');
      expect(authored.approachDistance, 32);
      expect(authored.instruction['en'], 'Water slows your movement.');
      expect(authored.instruction['fr'], introduction.instruction['fr']);
      expect(authored.spotlight.x, isNot(introduction.spotlight.x));
      expect(authored.reveals, isEmpty);
      result = null;
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(introduction.approachDistance, 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing water is repairable and cannot silently save a stale target',
    (tester) async {
      CampaignTutorialSequence? result;
      await mount(
        tester,
        introduction,
        (value) => result = value,
        missingWater: true,
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Select water region from this chunk.'), findsOneWidget);
      expect(find.byType(CampaignTutorialDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swimming hint reuses Jump authoring and retains necessary HUD', (
    tester,
  ) async {
    CampaignTutorialSequence? result;
    await mount(
      tester,
      CampaignSwimmingTutorial.introduction(),
      (value) => result = value,
    );
    expect(find.byType(JumpControl), findsOneWidget);
    final instruction = find.widgetWithText(TextFormField, 'Instruction (en)');
    await tester.ensureVisible(instruction);
    await tester.enterText(instruction, 'Use Jump to swim up.');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    final authored = result! as CampaignSwimmingTutorial;
    expect(authored.optional, isTrue);
    expect(authored.instruction['en'], 'Use Jump to swim up.');
    expect(authored.reveals, {
      TutorialHudElement.jump,
      TutorialHudElement.resources,
    });
    expect(authored.continuationAt(0), CampaignTutorialContinuation.jump);
    expect(tester.takeException(), isNull);
  });
}
