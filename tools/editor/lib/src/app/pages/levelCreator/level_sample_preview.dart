import 'package:flutter/material.dart';
import 'package:rpg_runner/playtest.dart';

/// Displays Core's selected stream. The coordinator supplies source thumbnails;
/// no scheduling, fallback, section, or spawn-roll logic lives in the widget.
class LevelSamplePreview extends StatelessWidget {
  const LevelSamplePreview({
    super.key,
    required this.scenario,
    required this.previewBuilder,
    required this.sourceName,
    required this.onSelected,
    this.joinedPreviewBuilder,
  });

  final LevelPlaytestScenario scenario;
  final Widget Function(String chunkKey) previewBuilder;
  final String Function(String chunkKey) sourceName;
  final ValueChanged<String> onSelected;
  final Widget Function(String leftKey, String rightKey)? joinedPreviewBuilder;

  @override
  Widget build(BuildContext context) {
    final sample = scenario.sampleChunks();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'First ${sample.length} chunks · seed ${scenario.seed} · the run continues beyond this sample',
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            key: const PageStorageKey('level_sample_scroll'),
            scrollDirection: Axis.horizontal,
            itemCount: sample.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = sample[index];
              final section = item.assembly;
              return SizedBox(
                width: 196,
                child: Card.outlined(
                  child: InkWell(
                    key: ValueKey('level_sample_${item.chunkIndex}'),
                    onTap: () => onSelected(item.chunkKey),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Chunk ${index + 1}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text('Source: ${sourceName(item.chunkKey)}'),
                            SizedBox(
                              height: 92,
                              child: index > 0 && joinedPreviewBuilder != null
                                  ? joinedPreviewBuilder!(
                                      sample[index - 1].chunkKey,
                                      item.chunkKey,
                                    )
                                  : previewBuilder(item.chunkKey),
                            ),
                            if (index > 0)
                              const Text(
                                'Matching entrance from previous chunk',
                              ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(
                                '${item.availableChunkKeys.length} choices at this position',
                              ),
                              children: [
                                for (final key in item.availableChunkKeys)
                                  TextButton(
                                    onPressed: () => onSelected(key),
                                    child: Text(sourceName(key)),
                                  ),
                              ],
                            ),
                            Text(
                              item.requestedTier == item.resolvedTier
                                  ? item.requestedTier.name
                                  : '${item.requestedTier.name} → ${item.resolvedTier.name} fallback',
                            ),
                            Text('Group: ${item.groupId}'),
                            if (item.enemiesSuppressed)
                              const Text('Opening: enemies suppressed'),
                            if (section != null)
                              Text(
                                '${item.startsSection ? 'Section starts · ' : ''}${section.segmentId}\n'
                                '${section.repeatsFinalSegment ? 'Final section repeats' : 'Cycle ${section.cycleIndex + 1}'} · ${section.chunkCount} chunks',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enemy suppression describes the opening rule. Spawn chances are still resolved during Play.',
        ),
      ],
    );
  }
}
