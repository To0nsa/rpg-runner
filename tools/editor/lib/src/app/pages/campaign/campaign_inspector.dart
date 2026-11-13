import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../chunks/chunk_v2_file_data.dart';

class CampaignInspector extends StatelessWidget {
  const CampaignInspector({
    super.key,
    required this.settings,
    required this.chunk,
    required this.missionChunkId,
    required this.usedBy,
    required this.onRewards,
    required this.onPreviewJournal,
    required this.onEditChunk,
    required this.diagnostics,
  });

  final Widget settings;
  final ChunkV2FileData? chunk;
  final String? missionChunkId;
  final List<String> usedBy;
  final VoidCallback onRewards;
  final VoidCallback onPreviewJournal;
  final VoidCallback? onEditChunk;
  final List<String> diagnostics;

  @override
  Widget build(BuildContext context) => ToolPanelCard(
    title: 'Mission Settings',
    bodyMode: ToolPanelBodyMode.expanded,
    child: ListView(
      key: const PageStorageKey('campaign_settings_scroll'),
      padding: const EdgeInsets.symmetric(vertical: ToolUiTokens.controlGap),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: onRewards,
              icon: const Icon(Icons.card_giftcard),
              label: const Text('First-clear mission rewards'),
            ),
            const SizedBox(height: ToolUiTokens.sectionGap),
            OutlinedButton.icon(
              onPressed: onPreviewJournal,
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('Preview Journal after this mission'),
            ),
            const SizedBox(height: ToolUiTokens.sectionGap),
            settings,
            if (chunk != null) ...[
              const Divider(height: 32),
              Text(
                missionChunkId == null
                    ? 'Selected chunk'
                    : 'Selected mission chunk',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: ToolUiTokens.controlGap),
              if (missionChunkId != null) ...[
                Text('Mission chunk ID: $missionChunkId'),
                const SizedBox(height: ToolUiTokens.rowTitleGap),
              ],
              Text(chunk!.chunkKey),
              const SizedBox(height: ToolUiTokens.rowTitleGap),
              Text(
                '${chunk!.levelId} · ${chunk!.usage} · ${chunk!.difficulty}',
              ),
              if (usedBy.isNotEmpty) ...[
                const SizedBox(height: ToolUiTokens.rowTitleGap),
                Text('Used by: ${usedBy.join(', ')}'),
              ],
              const SizedBox(height: ToolUiTokens.sectionGap),
              OutlinedButton.icon(
                onPressed: onEditChunk,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit chunk'),
              ),
            ],
            if (diagnostics.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'Validation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: ToolUiTokens.controlGap),
              for (final message in diagnostics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(message),
                ),
            ],
          ],
        ),
      ],
    ),
  );
}
