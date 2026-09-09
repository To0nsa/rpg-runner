import 'package:flutter/material.dart';

import '../../../levels/level_domain_models.dart';
import '../shared/editor_list_card.dart';
import '../shared/editor_panel_card.dart';

/// Compact Level selection; creation is a separate focused action.
class LevelLibrary extends StatelessWidget {
  const LevelLibrary({
    super.key,
    required this.levels,
    required this.selectedLevelId,
    required this.dirtyItemIds,
    required this.searchController,
    required this.onSelected,
    required this.onCreate,
    required this.previewBuilder,
    required this.countFor,
  });

  final List<LevelDef> levels;
  final String? selectedLevelId;
  final Set<String> dirtyItemIds;
  final TextEditingController searchController;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;
  final Widget Function(LevelDef level) previewBuilder;
  final int? Function(String levelId) countFor;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final visible = levels
        .where(
          (level) =>
              level.displayName.toLowerCase().contains(query) ||
              level.levelId.toLowerCase().contains(query),
        )
        .toList(growable: false);
    return EditorPanelCard(
      title: 'Levels',
      bodyMode: EditorPanelBodyMode.expanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const ValueKey<String>('new_level_button'),
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('New level'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('level_library_search'),
            controller: searchController,
            decoration: InputDecoration(
              labelText: 'Find level',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('No matching levels.'))
                : ListView.separated(
                    key: const ValueKey<String>('level_library_list'),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final level = visible[index];
                      final count = countFor(level.levelId);
                      return EditorListCard(
                        key: ValueKey<String>('level_library_${level.levelId}'),
                        isSelected: level.levelId == selectedLevelId,
                        onTap: () => onSelected(level.levelId),
                        preview: SizedBox(
                          width: 64,
                          height: 48,
                          child: previewBuilder(level),
                        ),
                        trailing:
                            dirtyItemIds.contains('level:${level.levelId}')
                            ? const Tooltip(
                                message: 'Unsaved changes',
                                child: Icon(Icons.circle, size: 10),
                              )
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                level.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                level.status == levelStatusDeprecated
                                    ? 'Deprecated'
                                    : count == null
                                    ? 'Content not loaded'
                                    : '$count active chunk${count == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                level.includeInBuild
                                    ? 'Included in Build'
                                    : 'Not included in Build',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
