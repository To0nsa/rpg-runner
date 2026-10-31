import 'package:flutter/material.dart';

import '../../components/progress_meter.dart';
import '../../state/ownership/achievement_progress.dart';
import '../../theme/ui_tokens.dart';
import 'achievement_presentation.dart';
import 'achievement_claim_action.dart';

/// Only the next target is visible until expanded; claim availability is separate
/// from expansion and from reaching the final tier.
class AchievementTile extends StatelessWidget {
  const AchievementTile({
    super.key,
    required this.entry,
    required this.presentation,
    required this.claiming,
    required this.onClaim,
  });
  final AchievementEntry entry;
  final AchievementPresentation presentation;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final next = entry.nextTier;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ui.radii.sm),
      side: BorderSide(color: ui.colors.outline),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: ui.space.sm),
      child: Material(
        color: ui.colors.cardBackground,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: PageStorageKey(entry.id),
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: ui.colors.accentStrong,
          collapsedIconColor: ui.colors.textMuted,
          tilePadding: EdgeInsets.all(ui.space.sm),
          childrenPadding: EdgeInsets.fromLTRB(
            ui.space.md,
            0,
            ui.space.md,
            ui.space.md,
          ),
          leading: Icon(presentation.icon, color: ui.colors.accentStrong),
          title: Text(presentation.title, style: ui.text.headline),
          subtitle: Padding(
            padding: EdgeInsets.only(top: ui.space.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (next != null) ...[
                  Text(
                    presentation.requirement(next.threshold),
                    style: ui.text.body,
                  ),
                  SizedBox(height: ui.space.xs),
                  ProgressMeter(
                    fraction: entry.value / next.threshold,
                    label:
                        '${presentation.quantity(entry.value)} / ${presentation.quantity(next.threshold)}',
                  ),
                  SizedBox(height: ui.space.xxs),
                  Text(
                    'Next reward: ${next.goldAmount} gold',
                    style: ui.text.body,
                  ),
                ] else
                  Text(
                    'Completed',
                    style: ui.text.body.copyWith(color: ui.colors.success),
                  ),
                if (entry.claimableGold > 0) ...[
                  SizedBox(height: ui.space.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AchievementClaimAction(
                      key: ValueKey('claim-${entry.id}'),
                      gold: entry.claimableGold,
                      onPressed: claiming ? null : onClaim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            Text(
              presentation.eligibility,
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
            for (var index = 0; index < entry.tiers.length; index += 1)
              _TierDetails(
                tier: entry.tiers[index],
                index: index,
                presentation: presentation,
              ),
          ],
        ),
      ),
    );
  }
}

class _TierDetails extends StatelessWidget {
  const _TierDetails({
    required this.tier,
    required this.index,
    required this.presentation,
  });
  final AchievementTier tier;
  final int index;
  final AchievementPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    const names = ['Bronze', 'Silver', 'Gold'];
    return Padding(
      padding: EdgeInsets.only(top: ui.space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: ui.colors.outline),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: ui.space.md,
            runSpacing: ui.space.xxs,
            children: [
              Text(names[index], style: ui.text.headline),
              Text(
                '${tier.goldAmount} gold · ${tier.claimedAtMs != null
                    ? 'Claimed'
                    : tier.achieved
                    ? 'Available'
                    : 'Not reached'}',
                style: ui.text.body,
              ),
            ],
          ),
          Text(presentation.requirement(tier.threshold), style: ui.text.body),
          if (tier.achievedAtMs != null)
            Text(
              'Achieved ${achievementDate(tier.achievedAtMs!)}',
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
        ],
      ),
    );
  }
}
