import 'package:flutter/material.dart';

import '../../../chunks/chunk_domain_models.dart';
import '../../../chunks/chunk_v2_file_data.dart';
import '../shared/editor_list_card.dart';

/// Browses actual authored chunks; filters organize the catalog and do not
/// change runtime selection. Metadata mutations remain Chunk-domain handoffs.
class LevelContents extends StatelessWidget {
  const LevelContents({
    super.key,
    required this.chunks,
    required this.groups,
    required this.groupFilter,
    required this.selectedChunkKey,
    required this.searchController,
    required this.onFilter,
    required this.onSelected,
    required this.onAddGroup,
    required this.onRemoveGroup,
    required this.onAddChunk,
    required this.onEditChunk,
    required this.onAssignChunk,
    required this.previewBuilder,
  });

  final List<ChunkV2FileData> chunks;
  final List<String> groups;
  final String? groupFilter;
  final String? selectedChunkKey;
  final TextEditingController searchController;
  final ValueChanged<String?> onFilter;
  final ValueChanged<String> onSelected;
  final VoidCallback onAddGroup;
  final ValueChanged<String> onRemoveGroup;
  final VoidCallback? onAddChunk;
  final ValueChanged<ChunkV2FileData>? onEditChunk;
  final ValueChanged<ChunkV2FileData>? onAssignChunk;
  final Widget Function(ChunkV2FileData) previewBuilder;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final visible = chunks
        .where(
          (chunk) =>
              (groupFilter == null || chunk.assemblyGroupId == groupFilter) &&
              (chunk.id.toLowerCase().contains(query) ||
                  chunk.difficulty.toLowerCase().contains(query) ||
                  chunk.tags.any((tag) => tag.toLowerCase().contains(query))),
        )
        .toList(growable: false);
    return ListView(
      key: const PageStorageKey<String>('level_contents_scroll'),
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: onAddChunk,
              icon: const Icon(Icons.add),
              label: const Text('Add chunk'),
            ),
            OutlinedButton.icon(
              onPressed: onAddGroup,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Add group'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Find chunk',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text('All (${chunks.length})'),
              selected: groupFilter == null,
              onSelected: (_) => onFilter(null),
            ),
            for (final group in groups)
              InputChip(
                key: ValueKey<String>('level_group_$group'),
                label: Text(
                  '$group (${chunks.where((chunk) => chunk.assemblyGroupId == group && chunk.status == chunkStatusActive).length})',
                ),
                selected: groupFilter == group,
                onSelected: (_) => onFilter(group),
                onDeleted: group == defaultChunkAssemblyGroupId
                    ? null
                    : () => onRemoveGroup(group),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Group filters organize this catalog. Automatic selection uses eligible content from every group.',
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              query.isNotEmpty
                  ? 'No chunks match this search.'
                  : 'No chunks yet${groupFilter == null ? '' : ' in $groupFilter'}. Add a chunk to populate this content pool.',
            ),
          ),
        for (final chunk in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EditorListCard(
              key: ValueKey<String>('level_chunk_${chunk.chunkKey}'),
              isSelected: selectedChunkKey == chunk.chunkKey,
              onTap: () => onSelected(chunk.chunkKey),
              preview: SizedBox(
                width: 120,
                height: 70,
                child: previewBuilder(chunk),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chunk.id,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${chunk.difficulty} · ${chunk.assemblyGroupId} · ${chunk.status == chunkStatusActive ? 'Active' : 'Deprecated — excluded from runs'}',
                    ),
                    Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: onEditChunk == null
                              ? null
                              : () => onEditChunk!(chunk),
                          child: const Text('Edit chunk'),
                        ),
                        TextButton(
                          onPressed: onAssignChunk == null
                              ? null
                              : () => onAssignChunk!(chunk),
                          child: const Text('Assign group'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
