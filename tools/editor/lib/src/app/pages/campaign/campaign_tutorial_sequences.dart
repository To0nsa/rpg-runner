import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:runner_core/terrain/water_region.dart';
import 'package:runner_core/track/chunk_pattern.dart';

import 'campaign_tutorial_hud_picker.dart';
export 'campaign_tutorial_dialog.dart';

/// Mission-owned ordered lessons. Every accepted edit returns to the page's
/// revision-guarded command rather than owning a second persistence path.
class CampaignTutorialSequences extends StatelessWidget {
  const CampaignTutorialSequences({
    super.key,
    required this.mission,
    required this.onEdit,
    required this.onRemove,
    required this.onInitialHudChanged,
    required this.onPreview,
    this.waterRegionsByChunk = const {},
    this.spritesByChunk = const {},
    this.gapsByChunk = const {},
    this.platformsByChunk = const {},
    this.shrines = const [],
  });
  final CampaignMissionSource mission;
  final ValueChanged<CampaignTutorialSequence> onEdit, onRemove;
  final ValueChanged<Set<TutorialHudElement>> onInitialHudChanged;
  final VoidCallback onPreview;
  final Map<String, List<WaterRegionData>> waterRegionsByChunk;
  final Map<String, List<ChunkVisualSpriteRel>> spritesByChunk;

  final Map<String, List<CampaignTutorialGap>> gapsByChunk;
  final Map<String, List<CampaignTutorialPlatform>> platformsByChunk;
  final List<CampaignTutorialShrine> shrines;

  List<CampaignEnemySource> get _enemies => mission.placements
      .whereType<CampaignEnemySource>()
      .where((e) => e.marker.chancePercent == 100)
      .toList();

  CampaignDecorationTutorial? get _decorationPreset {
    for (final entry in waterRegionsByChunk.entries) {
      final decoration = campaignTutorialDecorations(
        spritesByChunk[entry.key] ?? const [],
      ).firstOrNull;
      if (entry.value.isNotEmpty && decoration != null) {
        return CampaignDecorationTutorial.introduction(
          missionChunkId: entry.key,
          waterRegionId: entry.value.first.id,
          decorationPrefabKey: decoration.prefabKey!,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      CampaignTutorialHudPicker(
        title: 'Visible at mission start',
        value: mission.initialTutorialHud,
        requiredElements: const {TutorialHudElement.movement},
        onChanged: onInitialHudChanged,
      ),
      const Text(
        'Revealed elements stay visible for the attempt. Hidden abilities also block keyboard and mouse input. Pause and Exit remain available.',
      ),
      const SizedBox(height: 12),
      for (final sequence in mission.tutorialSequences)
        Card(
          key: ValueKey(sequence.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sequence.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${sequence.enabled ? "Enabled" : "Disabled"} · ${switch (sequence.trigger) {
                    CampaignTutorialTrigger.missionStart => "Mission start",
                    CampaignTutorialTrigger.enemyApproached => "Enemy approach · projectile practice · sword at melee reach",
                    CampaignTutorialTrigger.mobilityReached => "Dry ground at trigger · fresh Dash to continue",
                    CampaignTutorialTrigger.movementStarted => "After a short walk",
                    CampaignTutorialTrigger.firstCoinCollected => "First coin collected",
                    CampaignTutorialTrigger.chunkEntered => "Chunk entry · 3 steps",
                    CampaignTutorialTrigger.waterApproached => "Approaching water",
                    CampaignTutorialTrigger.firstSwimming => "First swim · optional hint",
                    CampaignTutorialTrigger.blessingApproached => "Shrine objective · practice · 2 reward pages",
                    CampaignTutorialTrigger.platformApproached => "Approaching a platform",
                    CampaignTutorialTrigger.gapApproached => "Approaching a dry gap",
                    CampaignTutorialTrigger.waterCleared => "Grounded beyond water",
                  }}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => onEdit(sequence),
                      child: const Text('Edit sequence'),
                    ),
                    OutlinedButton(
                      onPressed: sequence.enabled ? onPreview : null,
                      child: const Text('Preview sequence'),
                    ),
                    TextButton(
                      onPressed: () => onRemove(sequence),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
                if (sequence is CampaignBlessingTutorial)
                  Text(
                    '${sequence.shrineId} · ${sequence.approachDistance} world units before the shrine.',
                  ),
                if (sequence is CampaignMobilityTutorial)
                  Text(
                    '${sequence.missionChunkId} · X ${sequence.triggerX} world units. Waits until Dash is ready.',
                  ),
                if (sequence is CampaignJumpTutorial)
                  Text(
                    'Enter ${sequence.missionChunkId}: obstacle, Jump, then resources.',
                  ),
                if (sequence is CampaignCoinTutorial)
                  const Text(
                    'Preview starts the mission. Collect a coin to reach this lesson.',
                  ),
                if (sequence is CampaignWaterTutorial)
                  Text(
                    '${sequence.missionChunkId} / ${sequence.waterRegionId} · ${sequence.approachDistance} world units before the bank.',
                  ),
                if (sequence is CampaignPlatformTutorial)
                  Text(
                    '${sequence.missionChunkId} / ${sequence.platformPrefabKey} · ${sequence.approachDistance} world units before the platform.',
                  ),
                if (sequence is CampaignGapTutorial)
                  Text(
                    '${sequence.missionChunkId} / ${sequence.nearGroundShapeId} → ${sequence.farGroundShapeId} · ${sequence.approachDistance} world units before the edge.',
                  ),
                if (sequence is CampaignSwimmingTutorial)
                  const Text(
                    'Enter any pool to see this hint. Jumping across keeps it available without delaying other lessons.',
                  ),
                if (sequence is CampaignDecorationTutorial)
                  Text(
                    '${sequence.missionChunkId} / ${sequence.decorationPrefabKey} · Land beyond ${sequence.waterRegionId} to reach this lesson.',
                  ),
              ],
            ),
          ),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignMovementTutorial))
        FilledButton.icon(
          onPressed: () =>
              onEdit(CampaignMovementTutorial.movementIntroduction()),
          icon: const Icon(Icons.add),
          label: const Text('Add movement introduction'),
        ),
      if (!mission.tutorialSequences.any(
        (s) => s is CampaignObjectivesTutorial,
      ))
        OutlinedButton.icon(
          onPressed: () => onEdit(CampaignObjectivesTutorial.introduction()),
          icon: const Icon(Icons.add),
          label: const Text('Add objectives introduction'),
        ),
      if (mission.route.isNotEmpty &&
          !mission.tutorialSequences.any((s) => s is CampaignJumpTutorial))
        OutlinedButton.icon(
          onPressed: () => onEdit(
            CampaignJumpTutorial.introduction(
              missionChunkId:
                  mission.route[mission.route.length > 1 ? 1 : 0].id,
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add obstacles and jump sequence'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignCoinTutorial))
        OutlinedButton.icon(
          onPressed: () => onEdit(CampaignCoinTutorial.introduction()),
          icon: const Icon(Icons.add),
          label: const Text('Add first coin lesson'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignWaterTutorial))
        OutlinedButton.icon(
          onPressed:
              waterRegionsByChunk.values.every((waters) => waters.isEmpty)
              ? null
              : () {
                  final entry = waterRegionsByChunk.entries.firstWhere(
                    (e) => e.value.isNotEmpty,
                  );
                  onEdit(
                    CampaignWaterTutorial.introduction(
                      missionChunkId: entry.key,
                      waterRegionId: entry.value.first.id,
                    ),
                  );
                },
          icon: const Icon(Icons.add),
          label: const Text('Add water introduction'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignSwimmingTutorial))
        OutlinedButton.icon(
          onPressed: () => onEdit(CampaignSwimmingTutorial.introduction()),
          icon: const Icon(Icons.add),
          label: const Text('Add first swim hint'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignBlessingTutorial))
        OutlinedButton.icon(
          onPressed: shrines.isEmpty
              ? null
              : () => onEdit(
                  CampaignBlessingTutorial.introduction(
                    shrineId: shrines.first.id,
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Add blessing introduction'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignCombatTutorial))
        OutlinedButton.icon(
          onPressed: _enemies.isEmpty
              ? null
              : () => onEdit(
                  CampaignCombatTutorial.introduction(
                    missionChunkId: _enemies.first.missionChunkId,
                    markerSalt: _enemies.first.marker.salt,
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Add combat introduction'),
        ),
      if (mission.route.isNotEmpty &&
          !mission.tutorialSequences.any((s) => s is CampaignMobilityTutorial))
        OutlinedButton.icon(
          onPressed: () => onEdit(
            CampaignMobilityTutorial.introduction(
              missionChunkId: mission.route.first.id,
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add mobility introduction'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignPlatformTutorial))
        OutlinedButton.icon(
          onPressed: platformsByChunk.values.every((p) => p.isEmpty)
              ? null
              : () {
                  final entry = platformsByChunk.entries.firstWhere(
                    (e) => e.value.isNotEmpty,
                  );
                  onEdit(
                    CampaignPlatformTutorial.introduction(
                      missionChunkId: entry.key,
                      platformPrefabKey: entry.value.first.prefabKey,
                    ),
                  );
                },
          icon: const Icon(Icons.add),
          label: const Text('Add platforms introduction'),
        ),
      if (!mission.tutorialSequences.any((s) => s is CampaignGapTutorial))
        OutlinedButton.icon(
          onPressed: gapsByChunk.values.every((g) => g.isEmpty)
              ? null
              : () {
                  final entry = gapsByChunk.entries.firstWhere(
                    (e) => e.value.isNotEmpty,
                  );
                  final gap = entry.value.first;
                  onEdit(
                    CampaignGapTutorial.introduction(
                      missionChunkId: entry.key,
                      nearGroundShapeId: gap.nearGroundShapeId,
                      farGroundShapeId: gap.farGroundShapeId,
                    ),
                  );
                },
          icon: const Icon(Icons.add),
          label: const Text('Add gap crossing'),
        ),
      if (!mission.tutorialSequences.any(
        (s) => s is CampaignDecorationTutorial,
      ))
        OutlinedButton.icon(
          onPressed: _decorationPreset == null
              ? null
              : () => onEdit(_decorationPreset!),
          icon: const Icon(Icons.add),
          label: const Text('Add decorations introduction'),
        ),
    ],
  );
}
