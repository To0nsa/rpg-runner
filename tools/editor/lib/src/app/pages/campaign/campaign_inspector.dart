import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../chunks/chunk_v2_file_data.dart';

class CampaignInspector extends StatelessWidget {
  const CampaignInspector({
    super.key,
    required this.mission,
    required this.chunk,
    required this.occurrenceId,
    required this.usedBy,
    required this.onSettings,
    required this.onEditChunk,
    required this.diagnostics,
  });

  final CampaignMissionSource mission;
  final ChunkV2FileData? chunk;
  final String? occurrenceId;
  final List<String> usedBy;
  final VoidCallback onSettings;
  final VoidCallback? onEditChunk;
  final List<String> diagnostics;

  @override
  Widget build(BuildContext context) => ToolPanelCard(
    title: 'Settings',
    bodyMode: ToolPanelBodyMode.expanded,
    child: ListView(
      key: const PageStorageKey('campaign_settings_scroll'),
      children: [
        Text(
          mission.title['en']!,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(mission.description['en']!),
        const SizedBox(height: 12),
        Text(
          mission.includeInBuild
              ? 'Included in Build'
              : 'Draft · excluded from Build',
        ),
        Text(mission.combatAllowed ? 'Combat enabled' : 'No combat'),
        Text('First-clear XP: ${mission.firstClearXp}'),
        Text(
          'First-clear ability: ${mission.rewardAbilityId == null ? 'None' : 'Double jump'}',
        ),
        OutlinedButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.tune),
          label: const Text('Mission settings'),
        ),
        if (chunk != null) ...[
          const Divider(),
          Text(
            occurrenceId == null ? 'Selected chunk' : 'Selected occurrence',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (occurrenceId != null) Text(occurrenceId!),
          Text(chunk!.chunkKey),
          Text('${chunk!.levelId} · ${chunk!.usage} · ${chunk!.difficulty}'),
          if (usedBy.isNotEmpty) Text('Used by: ${usedBy.join(', ')}'),
          OutlinedButton.icon(
            onPressed: onEditChunk,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit chunk'),
          ),
        ],
        if (diagnostics.isNotEmpty) ...[
          const Divider(),
          Text('Validation', style: Theme.of(context).textTheme.titleMedium),
          for (final message in diagnostics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(message),
            ),
        ],
      ],
    ),
  );
}
