import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';
import 'package:tool_ui/tool_ui.dart';

/// Exact occurrence order, distinct from the Level Creator's random pool.
class CampaignRoute extends StatelessWidget {
  const CampaignRoute({
    super.key,
    required this.mission,
    required this.selectedOccurrenceId,
    required this.onSelected,
    required this.onMove,
    required this.onDuplicate,
    required this.onRemove,
    required this.onEdit,
    required this.onBrowse,
  });

  final CampaignMissionSource mission;
  final String? selectedOccurrenceId;
  final ValueChanged<String> onSelected;
  final void Function(int, int) onMove;
  final ValueChanged<int> onDuplicate, onRemove;
  final ValueChanged<int>? onEdit;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('campaign_route_scroll'),
    padding: const EdgeInsets.all(12),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: onBrowse,
          icon: const Icon(Icons.add),
          label: const Text('Add chunk'),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${mission.route.length} / 16 occurrences · exact route order · camera follows both directions',
      ),
      if (mission.route.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No chunks yet. Choose a chunk in Contents to begin this mission.',
          ),
        ),
      for (var i = 0; i < mission.route.length; i++)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ToolListCard(
            key: ValueKey('campaign_occurrence_${mission.route[i].id}'),
            isSelected: mission.route[i].id == selectedOccurrenceId,
            onTap: () => onSelected(mission.route[i].id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}. ${mission.route[i].chunkKey}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(mission.route[i].id),
                Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Move left',
                      onPressed: i == 0 ? null : () => onMove(i, i - 1),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton(
                      tooltip: 'Move right',
                      onPressed: i == mission.route.length - 1
                          ? null
                          : () => onMove(i, i + 1),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    IconButton(
                      tooltip: 'Duplicate occurrence',
                      onPressed: mission.route.length >= 16
                          ? null
                          : () => onDuplicate(i),
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton(
                      tooltip: 'Edit shared chunk / copy mode',
                      onPressed: onEdit == null ? null : () => onEdit!(i),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Remove occurrence',
                      onPressed: () => onRemove(i),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
