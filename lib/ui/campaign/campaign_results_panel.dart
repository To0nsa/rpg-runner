import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:runner_core/abilities/ability_def.dart';
import 'package:runner_core/players/player_character_definition.dart';

import '../components/app_button.dart';
import '../l10n/app_localization.dart';
import '../state/app/app_state.dart';
import '../theme/ui_tokens.dart';
import 'campaign_catalog.dart';

/// Unlock presentation reads canonical progress, never the local completion event.
class CampaignResultsPanel extends StatefulWidget {
  const CampaignResultsPanel({
    super.key,
    required this.missionId,
    required this.completed,
    this.onNext,
  });
  final String missionId;
  final bool completed;
  final ValueChanged<String>? onNext;
  @override
  State<CampaignResultsPanel> createState() => _CampaignResultsPanelState();
}

class _CampaignResultsPanelState extends State<CampaignResultsPanel> {
  bool _equipping = false;
  bool _equipFailed = false;

  Future<void> _equip(AppState state, String abilityId) async {
    setState(() {
      _equipping = true;
      _equipFailed = false;
    });
    try {
      await state.setAbilitySlot(
        characterId: PlayerCharacterId.eloise,
        slot: AbilitySlot.jump,
        abilityId: abilityId,
      );
    } catch (_) {
      if (mounted) setState(() => _equipFailed = true);
    } finally {
      if (mounted) setState(() => _equipping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionId = widget.missionId;
    final onNext = widget.onNext;
    final state = context.watch<AppState>();
    final mission = CampaignCatalog.mission(missionId);
    if (mission == null) return const SizedBox.shrink();
    final language = Localizations.localeOf(context).languageCode;
    CampaignMission? next;
    for (final chapter in CampaignCatalog.chapters) {
      final index = chapter.missions.indexWhere(
        (entry) => entry.id == missionId,
      );
      if (index >= 0 && index + 1 < chapter.missions.length) {
        next = chapter.missions[index + 1];
      }
    }
    final progress = state.progression.campaign;
    final best = progress.bestScore(missionId);
    final ability = mission.rewardAbilityId;
    final owned =
        ability != null &&
        state.meta
            .abilityOwnershipFor(PlayerCharacterId.eloise)
            .learnedAbilityIdsForSlot(AbilitySlot.jump)
            .contains(ability);
    final equipped =
        state.selection.loadoutFor(PlayerCharacterId.eloise).abilityJumpId ==
        ability;
    final chapterComplete = CampaignCatalog.chapters.any(
      (chapter) =>
          chapter.missions.any((entry) => entry.id == missionId) &&
          progress.chapterCleared(chapter),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mission.title(language), style: context.ui.text.title),
          const SizedBox(height: 12),
          Text(context.l10n.campaignFirstClearXp(xp: mission.firstClearXp)),
          if (mission.rewardAbilityId != null)
            Text(context.l10n.campaignDoubleJumpReward),
          const SizedBox(height: 12),
          Text(
            state.isDeveloperMode
                ? context.l10n.practiceNoRewards
                : progress.isCleared(missionId)
                ? context.l10n.runMissionCompleted
                : widget.completed
                ? context.l10n.campaignVerificationPending
                : context.l10n.runMissionFailed,
          ),
          if (best != null) Text(context.l10n.campaignBestScore(score: best)),
          if (!state.isDeveloperMode && chapterComplete)
            Text(context.l10n.campaignWillowUnlocked),
          if (!state.isDeveloperMode && owned) ...[
            const SizedBox(height: 12),
            AppButton(
              label: equipped
                  ? context.l10n.campaignDoubleJumpEquipped
                  : context.l10n.campaignEquipDoubleJump,
              onPressed: equipped || _equipping
                  ? null
                  : () => _equip(state, ability),
            ),
            if (_equipFailed) Text(context.l10n.campaignEquipFailed),
          ],
          if (next != null) ...[
            const SizedBox(height: 16),
            AppButton(
              label: context.l10n.campaignNextMission,
              onPressed:
                  next.available &&
                      (state.isDeveloperMode || progress.isUnlocked(next)) &&
                      onNext != null
                  ? () => onNext(next!.id)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
