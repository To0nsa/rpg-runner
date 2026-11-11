import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/app_button.dart';
import '../l10n/app_localization.dart';
import '../state/app/app_state.dart';
import '../theme/ui_tokens.dart';
import 'campaign_catalog.dart';

/// Chapter selection stays over the map in a full-height, left two-thirds panel.
/// Content scrolls independently of the title and dismiss control.
class CampaignChapterDialog extends StatefulWidget {
  const CampaignChapterDialog({super.key, required this.chapter});

  final CampaignChapter chapter;

  @override
  State<CampaignChapterDialog> createState() => _CampaignChapterDialogState();
}

class _CampaignChapterDialogState extends State<CampaignChapterDialog> {
  bool _starting = false;

  Future<void> _start(CampaignMission mission) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await Navigator.of(context).pushNamed(
        UiRoutes.runBootstrap,
        arguments: RunStartBootstrapArgs(campaignMissionId: mission.id),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final chapter = widget.chapter;
    final state = context.watch<AppState>();
    final ui = context.ui;
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      alignment: Alignment.centerLeft,
      insetPadding: EdgeInsets.zero,
      // Override Dialog's minimum width so portrait keeps the same proportion.
      constraints: const BoxConstraints(),
      backgroundColor: ui.colors.background,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(ui.radii.md),
          bottomRight: Radius.circular(ui.radii.md),
        ),
        side: BorderSide(color: ui.colors.outline),
      ),
      child: SizedBox(
        key: const ValueKey('campaign-chapter-panel'),
        width: viewport.width * 2 / 3,
        height: viewport.height,
        child: SafeArea(
          right: false,
          child: DefaultTextStyle(
            style: ui.text.body,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: ui.space.md,
                    right: ui.space.xs,
                    top: ui.space.xs,
                    bottom: ui.space.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          namesRoute: true,
                          header: true,
                          child: Text(
                            chapter.title(language),
                            style: ui.text.title,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.uiClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: ui.colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      ui.space.md,
                      ui.space.xs,
                      ui.space.md,
                      ui.space.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(chapter.description(language)),
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < chapter.missions.length;
                          index++
                        )
                          _missionCard(
                            chapter.missions[index],
                            index,
                            state,
                            language,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _missionCard(
    CampaignMission mission,
    int index,
    AppState state,
    String language,
  ) {
    final progress = state.progression.campaign;
    final unlocked = state.isDeveloperMode || progress.isUnlocked(mission);
    final cleared = progress.isCleared(mission.id);
    final score = progress.bestScore(mission.id);
    final ui = context.ui;
    return Card(
      color: ui.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.md),
        side: BorderSide(color: ui.colors.outline),
      ),
      child: DefaultTextStyle(
        style: ui.text.body,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    cleared
                        ? Icons.check_circle_outline
                        : unlocked
                        ? Icons.flag_outlined
                        : Icons.lock_outline,
                    color: ui.colors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${index + 1}. ${mission.title(language)}',
                      style: ui.text.title,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(mission.description(language), style: ui.text.body),
              if (score != null || !unlocked) const SizedBox(height: 6),
              if (score != null)
                Text(context.l10n.campaignBestScore(score: score)),
              if (!unlocked) Text(context.l10n.campaignPreviousRequired),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  label: !mission.available
                      ? context.l10n.campaignComingSoon
                      : cleared
                      ? context.l10n.campaignReplay
                      : context.l10n.campaignStart,
                  onPressed: mission.available && unlocked && !_starting
                      ? () => _start(mission)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
