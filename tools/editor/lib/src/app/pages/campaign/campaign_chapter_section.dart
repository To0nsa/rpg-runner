import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

/// Chapter-local expansion is presentation state, never a content edit.
/// Selection restored by navigation/history reveals its owning chapter.
class CampaignChapterSection extends StatefulWidget {
  const CampaignChapterSection({
    super.key,
    required this.chapter,
    required this.number,
    required this.selectedMissionId,
    required this.onSettings,
    required this.onRewards,
    required this.onAddMission,
    this.onDeleteMission,
    required this.onSelectMission,
    required this.onReorderMission,
  });
  final CampaignChapterSource chapter;
  final int number;
  final String selectedMissionId;
  final VoidCallback onSettings, onRewards, onAddMission;
  final VoidCallback? onDeleteMission;
  final ValueChanged<String> onSelectMission;
  final void Function(String, int) onReorderMission;

  @override
  State<CampaignChapterSection> createState() => _CampaignChapterSectionState();
}

class _CampaignChapterSectionState extends State<CampaignChapterSection> {
  final _expansion = ExpansibleController();

  bool get _containsSelection =>
      widget.chapter.missions.any((m) => m.id == widget.selectedMissionId);

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _containsSelection) _expansion.expand();
    });
  }

  @override
  void didUpdateWidget(CampaignChapterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMissionId != widget.selectedMissionId &&
        _containsSelection) {
      _revealSelection();
    }
  }

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    return ExpansionTile(
      key: PageStorageKey('campaign_chapter_${chapter.id}'),
      controller: _expansion,
      initiallyExpanded: _containsSelection,
      title: Text('Chapter ${widget.number}'),
      subtitle: Text(chapter.title['en']!),
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: widget.onSettings,
              child: const Text('Chapter settings'),
            ),
            OutlinedButton(
              onPressed: widget.onRewards,
              child: const Text('Chapter rewards'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < chapter.missions.length; i++)
          ListTile(
            key: ValueKey('campaign_mission_${chapter.missions[i].id}'),
            selected: chapter.missions[i].id == widget.selectedMissionId,
            title: Text('${i + 1}. ${chapter.missions[i].title['en']}'),
            subtitle: Text(
              chapter.missions[i].includeInBuild
                  ? (i == 0
                        ? 'Included · first mission'
                        : 'Included · previous mission required')
                  : 'Draft · excluded from Build',
            ),
            onTap: () => widget.onSelectMission(chapter.missions[i].id),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move mission earlier',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0
                      ? null
                      : () => widget.onReorderMission(
                          chapter.missions[i].id,
                          i - 1,
                        ),
                ),
                IconButton(
                  tooltip: 'Move mission later',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == chapter.missions.length - 1
                      ? null
                      : () => widget.onReorderMission(
                          chapter.missions[i].id,
                          i + 1,
                        ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: chapter.missions.length < 16
                  ? widget.onAddMission
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Add mission'),
            ),
            Tooltip(
              message: chapter.missions.length <= 1
                  ? 'A chapter needs at least one mission.'
                  : _containsSelection
                  ? 'Delete the selected mission'
                  : 'Select a mission in this chapter first',
              child: OutlinedButton.icon(
                onPressed: chapter.missions.length > 1 && _containsSelection
                    ? widget.onDeleteMission
                    : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete mission'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
