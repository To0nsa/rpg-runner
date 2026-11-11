import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';

import '../app/ui_routes.dart';
import '../components/app_button.dart';
import '../components/menu_layout.dart';
import '../components/menu_scaffold.dart';
import '../l10n/app_localization.dart';
import '../state/app/app_state.dart';
import '../theme/ui_tokens.dart';
import '../text/build_name_text.dart';
import 'campaign_catalog.dart';
import 'campaign_chapter_rewards.dart';
import 'campaign_map.dart';

/// Campaign navigation keeps runner selection unchanged and opens the shared run host.
class CampaignPage extends StatefulWidget {
  const CampaignPage({super.key});
  @override
  State<CampaignPage> createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage> {
  CampaignChapter? _chapter;
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
    final chapter = _chapter;
    final state = context.watch<AppState>();
    final ui = context.ui;
    return PopScope<Object?>(
      canPop: chapter == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && chapter != null) setState(() => _chapter = null);
      },
      child: MenuScaffold(
        title: chapter?.title(language) ?? context.l10n.campaignHeading,
        child: chapter == null
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(
                    constraints.maxWidth,
                    constraints.maxHeight * 1361 / 1156,
                  );
                  final height = width * 1156 / 1361;
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              campaignRegionalMapAsset,
                              fit: BoxFit.fill,
                            ),
                          ),
                          for (final entry in CampaignCatalog.chapters)
                            Positioned(
                              left:
                                  (width * entry.mapX -
                                          math.min(220, width) / 2)
                                      .clamp(
                                        0,
                                        math.max(
                                          0,
                                          width - math.min(220, width),
                                        ),
                                      ),
                              top: height * entry.mapY - 20,
                              width: math.min(220, width),
                              child: AppButton(
                                label: entry.title(language),
                                icon: Icons.flag_outlined,
                                onPressed: () =>
                                    setState(() => _chapter = entry),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : MenuLayout(
                maxWidth: 1100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _chapter = null),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          context.l10n.campaignRegionalMap,
                          style: ui.text.body,
                        ),
                      ),
                    ),
                    Text(chapter.description(language), style: ui.text.body),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed(UiRoutes.selectCharacter),
                      icon: const Icon(Icons.person_outline),
                      label: Text(
                        '${characterDisplayName(state.selection.selectedCharacterId, strings: context.gameL10n)} · ${buildDisplayName(state.selection.buildName, state.selection.selectedBuildIndexFor(state.selection.selectedCharacterId), context.l10n)}',
                        style: ui.text.body,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CampaignChapterRewards(chapter: chapter),
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
          child: Row(
            children: [
              Icon(
                cleared
                    ? Icons.check_circle_outline
                    : unlocked
                    ? Icons.flag_outlined
                    : Icons.lock_outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${mission.title(language)}',
                      style: ui.text.title,
                    ),
                    Text(mission.description(language), style: ui.text.body),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.campaignFirstClearXp(
                        xp: mission.firstClearXp,
                      ),
                      style: ui.text.cardSubtitle,
                    ),
                    if (mission.rewardAbilityId != null)
                      Text(context.l10n.campaignDoubleJumpReward),
                    Text(context.l10n.campaignCollectedGold),
                    if (score != null)
                      Text(context.l10n.campaignBestScore(score: score)),
                    if (!unlocked) Text(context.l10n.campaignPreviousRequired),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: !mission.available
                    ? context.l10n.campaignComingSoon
                    : cleared
                    ? context.l10n.campaignReplay
                    : context.l10n.campaignStart,
                onPressed: mission.available && unlocked && !_starting
                    ? () => _start(mission)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
