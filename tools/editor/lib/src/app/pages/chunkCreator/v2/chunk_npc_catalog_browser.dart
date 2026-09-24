import 'package:flutter/material.dart';
import 'package:runner_core/npcs/npc_catalog.dart';
import 'package:runner_core/npcs/npc_id.dart';

import '../../shared/editor_scene_view_utils.dart';
import '../../shared/editor_visual_catalog.dart';
import 'chunk_actor_catalog_thumbnail.dart';
import 'chunk_actor_idle_frame.dart';

String npcDisplayName(NpcId id) => switch (id) {
  NpcId.warrior => 'Warrior',
  NpcId.huntress => 'Huntress',
  NpcId.huntress2 => 'Huntress II',
};

/// Selecting a card only chooses a placement tool; it does not edit source.
class ChunkNpcCatalogBrowser extends StatefulWidget {
  const ChunkNpcCatalogBrowser({
    super.key,
    required this.workspaceRootPath,
    required this.selected,
    required this.onSelected,
    required this.enabled,
  });
  final String workspaceRootPath;
  final NpcId? selected;
  final ValueChanged<NpcId> onSelected;
  final bool enabled;
  @override
  State<ChunkNpcCatalogBrowser> createState() => _ChunkNpcCatalogBrowserState();
}

class _ChunkNpcCatalogBrowserState extends State<ChunkNpcCatalogBrowser> {
  final _search = TextEditingController();
  final _images = EditorUiImageCache();
  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _search.dispose();
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ids = NpcCatalog.supportedIds
        .where(
          (id) => '${id.name} ${npcDisplayName(id)}'.toLowerCase().contains(
            _search.text.trim().toLowerCase(),
          ),
        )
        .toList();
    return EditorVisualCatalogLayout(
      searchController: _search,
      searchKey: const ValueKey('chunk_npc_search'),
      searchLabel: 'Search NPCs',
      searchHint: 'Name or ID',
      clearSearchKey: const ValueKey('chunk_npc_clear_search'),
      clearSearchTooltip: 'Clear NPC search',
      filters: const [],
      countKey: const ValueKey('chunk_npc_count'),
      countLabel: '${ids.length} NPCs',
      gridKey: const ValueKey('chunk_npc_grid'),
      emptyKey: const ValueKey('chunk_npc_empty'),
      emptyMessage: 'No NPCs match the search.',
      itemCount: ids.length,
      enabled: widget.enabled,
      gridHeight: 190,
      onSearchSubmitted: () {
        if (ids.isNotEmpty) widget.onSelected(ids.first);
      },
      itemBuilder: (context, index) {
        final id = ids[index];
        final actor = const NpcCatalog().get(id);
        return EditorVisualCatalogCard(
          key: ValueKey('chunk_npc_card_${id.name}'),
          semanticsLabel: npcDisplayName(id),
          tooltipMessage: npcDisplayName(id),
          selected: widget.selected == id,
          enabled: widget.enabled,
          preview: ChunkActorCatalogThumbnail(
            imageCache: _images,
            frame: ChunkActorIdleFrame.fromDefinition(
              renderAnim: actor.renderAnim,
              renderScale: actor.renderScale,
              workspaceRootPath: widget.workspaceRootPath,
            ),
          ),
          title: npcDisplayName(id),
          subtitle: id == NpcId.warrior ? 'Melee ally' : 'Ranged ally',
          onTap: () => widget.onSelected(id),
        );
      },
    );
  }
}
