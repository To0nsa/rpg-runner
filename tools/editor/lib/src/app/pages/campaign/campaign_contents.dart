import 'package:flutter/material.dart';

import '../../../chunks/chunk_v2_file_data.dart';
import '../shared/authored_chunk_card.dart';

/// Catalog browsing only; the route supplies exact-order insertion commands.
class CampaignContents extends StatelessWidget {
  const CampaignContents({
    super.key,
    required this.chunks,
    required this.searchController,
    required this.selectedChunkKey,
    required this.onSelected,
    required this.onAppend,
    required this.onEdit,
    required this.previewBuilder,
  });

  final List<ChunkV2FileData> chunks;
  final TextEditingController searchController;
  final String? selectedChunkKey;
  final ValueChanged<ChunkV2FileData> onSelected;
  final ValueChanged<ChunkV2FileData>? onAppend, onEdit;
  final Widget Function(ChunkV2FileData) previewBuilder;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final visible = chunks
        .where(
          (c) =>
              '${c.levelId} ${c.assemblyGroupId} ${c.difficulty} ${c.chunkKey} ${c.usage} ${c.tags.join(' ')}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return ListView(
      key: const PageStorageKey('campaign_contents_scroll'),
      padding: const EdgeInsets.all(12),
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Find chunk',
            hintText: 'Region, group, tier, usage or key',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Append chunks in route order. Edit chunk opens Chunk Creator, where Copy to Campaign creates an independent layout.',
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty) const Text('No chunks match this search.'),
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
                  label: const Text('Append occurrence'),
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
}
