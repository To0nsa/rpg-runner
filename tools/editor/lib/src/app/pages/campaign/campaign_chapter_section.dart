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
    required this.onSelectMission,
    required this.onMoveEarlier,
  });
  final CampaignChapterSource chapter;
  final int number;
  final String selectedMissionId;
  final VoidCallback onSettings, onRewards, onAddMission;
  final ValueChanged<String> onSelectMission;
  final void Function(String, int) onMoveEarlier;

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
      children: [
        Text(chapter.description['en']!),
        Text(
          'Chapter reward: ${chapter.rewardCharacterId == null ? 'None' : 'Willow'} · ${chapter.missions.fold<int>(0, (sum, m) => sum + m.firstClearXp)} XP',
        ),
        Wrap(
          spacing: 8,
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
        for (var i = 0; i < chapter.missions.length; i++)
          ListTile(
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
            trailing: i == 0
                ? null
                : IconButton(
                    tooltip: 'Move mission earlier',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () =>
                        widget.onMoveEarlier(chapter.missions[i].id, i - 1),
                  ),
          ),
        OutlinedButton.icon(
          onPressed: chapter.missions.length < 16 ? widget.onAddMission : null,
          icon: const Icon(Icons.add),
          label: const Text('Add mission'),
        ),
      ],
    );
  }
}
