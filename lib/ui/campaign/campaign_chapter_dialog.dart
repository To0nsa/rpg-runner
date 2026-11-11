import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/ui_routes.dart';
import '../components/app_button.dart';
import '../l10n/app_localization.dart';
import '../state/app/app_state.dart';
import '../theme/ui_button_theme.dart';
import '../theme/ui_tokens.dart';
import 'campaign_catalog.dart';

/// Chapter selection occupies the left two-thirds of the system-safe width.
/// An outer margin keeps it off screen edges even when safe insets are zero.
/// Content scrolls independently of the title and dismiss control.
class CampaignChapterDialog extends StatefulWidget {
  const CampaignChapterDialog({super.key, required this.chapter});

  final CampaignChapter chapter;

  @override
  State<CampaignChapterDialog> createState() => _CampaignChapterDialogState();
}

class _CampaignChapterDialogState extends State<CampaignChapterDialog> {
  bool _starting = false;
  final Set<String> _expandedMissions = {};

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
    return LayoutBuilder(
      builder: (context, constraints) => Dialog(
        alignment: Alignment.centerLeft,
        insetPadding: EdgeInsets.all(ui.space.sm),
        // Override Dialog's minimum width so portrait keeps the same proportion.
        constraints: const BoxConstraints(),
        backgroundColor: ui.colors.background,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ui.radii.md),
          side: BorderSide(color: ui.colors.outline),
        ),
        child: SizedBox(
          key: const ValueKey('campaign-chapter-panel'),
          width: constraints.maxWidth * 2 / 3,
          height: constraints.maxHeight,
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
                            style: ui.text.title.copyWith(inherit: false),
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
                        for (final mission in chapter.missions)
                          _missionCard(mission, state, language),
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
    AppState state,
    String language,
  ) {
    final progress = state.progression.campaign;
    final unlocked = state.isDeveloperMode || progress.isUnlocked(mission);
    final cleared = progress.isCleared(mission.id);
    final score = progress.bestScore(mission.id);
    final expanded = unlocked && _expandedMissions.contains(mission.id);
    final title = unlocked
        ? mission.title(language)
        : context.l10n.campaignLocked;
    final ui = context.ui;
    return Card(
      key: ValueKey('campaign-mission-${mission.id}'),
      color: ui.colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radii.md),
        side: BorderSide(color: ui.colors.outline),
      ),
      child: DefaultTextStyle(
        // Keep button measurement and painting free of Material text defaults.
        style: ui.text.body.copyWith(inherit: false),
        child: Padding(
          padding: EdgeInsets.all(ui.space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      key: ValueKey('campaign-mission-details-${mission.id}'),
                      container: true,
                      button: unlocked,
                      expanded: unlocked ? expanded : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(ui.radii.sm),
                        onTap: !unlocked
                            ? null
                            : () => setState(() {
                                if (expanded) {
                                  _expandedMissions.remove(mission.id);
                                } else {
                                  _expandedMissions.add(mission.id);
                                }
                              }),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: ui.sizes.tapTarget,
                          ),
                          child: Row(
                            children: [
                              if (unlocked) ...[
                                Icon(
                                  expanded
                                      ? Icons.expand_more
                                      : Icons.chevron_right,
                                  size: 20,
                                  color: ui.colors.textPrimary,
                                ),
                                SizedBox(width: ui.space.xxs),
                              ],
                              Expanded(
                                child: Tooltip(
                                  message: title,
                                  excludeFromSemantics: true,
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ui.text.headline.copyWith(
                                      inherit: false,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: ui.space.xs),
                  SizedBox(
                    width: context.buttons.sizes.width(AppButtonSize.sm),
                    child: AppButton(
                      size: AppButtonSize.xxs,
                      label: !mission.available
                          ? context.l10n.campaignComingSoon
                          : unlocked
                          ? context.l10n.playButton
                          : context.l10n.campaignLocked,
                      icon: mission.available && !unlocked
                          ? Icons.lock_outline
                          : null,
                      onPressed: mission.available && unlocked && !_starting
                          ? () => _start(mission)
                          : null,
                    ),
                  ),
                ],
              ),
              if (expanded)
                Padding(
                  padding: EdgeInsets.only(top: ui.space.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(mission.description(language), style: ui.text.body),
                      if (cleared || score != null) const SizedBox(height: 6),
                      if (cleared) Text(context.l10n.uiCompleted),
                      if (score != null)
                        Text(context.l10n.campaignBestScore(score: score)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
