import 'package:flutter/material.dart';
import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';

import '../l10n/app_localization.dart';
import '../theme/ui_tokens.dart';
import 'campaign_catalog.dart';

/// Authored completion rewards use the same names and icons as the inventory.
class CampaignChapterRewards extends StatelessWidget {
  const CampaignChapterRewards({super.key, required this.chapter});
  final CampaignChapter chapter;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.campaignChapterReward,
        style: context.ui.text.cardSubtitle,
      ),
      if (chapter.rewardXp > 0 || chapter.rewardGold > 0)
        Text(
          context.l10n.campaignChapterRewardAmounts(
            xp: chapter.rewardXp,
            gold: chapter.rewardGold,
          ),
        ),
      if (chapter.rewardCharacter case final character?)
        Text(characterDisplayName(character, strings: context.gameL10n)),
      for (final item in chapter.rewardItems)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              item.item.icon(size: 32),
              const SizedBox(width: 8),
              Expanded(child: Text(item.label(context.gameL10n))),
            ],
          ),
        ),
    ],
  );
}
