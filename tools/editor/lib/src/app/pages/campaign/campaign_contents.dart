import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../shared/authored_chunk_card.dart';

/// Catalog browsing only; the route supplies exact-order insertion commands.
class CampaignContents extends StatelessWidget {
  const CampaignContents({
    super.key,
    required this.chunks,
    required this.searchController,
    required this.groupFilter,
    required this.difficultyFilter,
    required this.onGroupFilterChanged,
    required this.onDifficultyFilterChanged,
    required this.onClearFilters,
    required this.selectedChunkKey,
    required this.onSelected,
    required this.onAppend,
    required this.onEdit,
    required this.previewBuilder,
  });

  final List<ChunkV2FileData> chunks;
  final TextEditingController searchController;
  final String groupFilter, difficultyFilter;
  final ValueChanged<String> onGroupFilterChanged, onDifficultyFilterChanged;
  final VoidCallback onClearFilters;
  final String? selectedChunkKey;
  final ValueChanged<ChunkV2FileData> onSelected;
  final ValueChanged<ChunkV2FileData>? onAppend, onEdit;
  final Widget Function(ChunkV2FileData) previewBuilder;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final campaignChunks = chunks.where((c) => c.usage == 'campaign').toList();
    final groups = campaignChunks.map((c) => c.assemblyGroupId).toSet().toList()
      ..sort();
    final difficulties = [
      chunkDifficultyEarly,
      chunkDifficultyEasy,
      chunkDifficultyNormal,
      chunkDifficultyHard,
    ].where((tier) => campaignChunks.any((c) => c.difficulty == tier)).toList();
    final visible = campaignChunks
        .where(
          (c) =>
              (groupFilter.isEmpty || c.assemblyGroupId == groupFilter) &&
              (difficultyFilter.isEmpty || c.difficulty == difficultyFilter) &&
              '${c.levelId} ${c.assemblyGroupId} ${c.difficulty} ${c.chunkKey} ${c.usage} ${c.tags.join(' ')}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return ListView(
      key: const PageStorageKey('campaign_contents_scroll'),
      padding: const EdgeInsets.all(12),
      children: [
        ToolVisualCatalogControls(
          searchController: searchController,
          searchKey: const ValueKey('campaign_chunk_search'),
          searchLabel: 'Find chunk',
          searchHint: 'Region, group, tier, tag or key',
          clearSearchKey: const ValueKey('campaign_chunk_clear_search'),
          clearSearchTooltip: 'Clear chunk search',
          filters: [
            _filter('Group', groupFilter, groups, onGroupFilterChanged),
            _filter(
              'Difficulty',
              difficultyFilter,
              difficulties,
              onDifficultyFilterChanged,
            ),
            TextButton.icon(
              onPressed:
                  searchController.text.isNotEmpty ||
                      groupFilter.isNotEmpty ||
                      difficultyFilter.isNotEmpty
                  ? onClearFilters
                  : null,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Clear filters'),
            ),
          ],
          countKey: const ValueKey('campaign_chunk_filter_count'),
          countLabel: '${visible.length} of ${campaignChunks.length} chunks',
          onSearchSubmitted: () {
            if (visible.isNotEmpty) onSelected(visible.first);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Append campaign chunks in route order. To reuse a runner layout, open Chunk Creator and use Copy to Campaign.',
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const Text('No campaign chunks match this search or filters.'),
        for (final chunk in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AuthoredChunkCard(
              key: ValueKey('campaign_chunk_${chunk.chunkKey}'),
              chunk: chunk,
              isSelected: selectedChunkKey == chunk.chunkKey,
              onTap: () => onSelected(chunk),
              preview: previewBuilder(chunk),
              description:
                  '${chunk.levelId} · ${chunk.assemblyGroupId} · ${chunk.difficulty} · ${chunk.usage} · ${chunk.status}',
              actions: [
                TextButton.icon(
                  onPressed: onAppend == null ? null : () => onAppend!(chunk),
                  icon: const Icon(Icons.add),
                  label: const Text('Append chunk'),
                ),
                TextButton(
                  onPressed: onEdit == null ? null : () => onEdit!(chunk),
                  child: const Text('Edit chunk'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filter(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      key: ValueKey('campaign_${label.toLowerCase()}_filter_$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: '',
          child: Text(label == 'Group' ? 'All groups' : 'All difficulties'),
        ),
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: (value) => onChanged(value ?? ''),
    ),
  );
}
