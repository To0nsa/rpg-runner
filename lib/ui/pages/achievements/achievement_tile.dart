import 'package:flutter/material.dart';

import '../../l10n/app_localization.dart';
import '../../state/ownership/achievement_progress.dart';
import '../../theme/ui_tokens.dart';
import 'achievement_claim_action.dart';
import 'achievement_presentation.dart';
import 'achievement_tier_ledger.dart';

/// The next goal stays independent of earned rewards. Expansion reveals the
/// ledger without changing claim availability or account-scoped history state.
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
    final l10n = context.l10n;
    final next = entry.nextTier;
    final progress = next == null
        ? l10n.uiCompleted
        : l10n.progressQuantities(
            current: presentation.quantity(entry.value, l10n),
            target: presentation.quantity(next.threshold, l10n),
          );
    final requirement = presentation.requirement(
      next?.threshold ?? entry.tiers.last.threshold,
      l10n,
    );
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
          tilePadding: EdgeInsets.symmetric(
            horizontal: ui.space.sm,
            vertical: ui.space.xs,
          ),
          childrenPadding: EdgeInsets.symmetric(horizontal: ui.space.sm),
          title: LayoutBuilder(
            builder: (context, constraints) {
              final summary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        presentation.icon,
                        color: ui.colors.accentStrong,
                        size: ui.sizes.iconSize.sm,
                      ),
                      SizedBox(width: ui.space.xs),
                      Expanded(
                        child: Text(
                          presentation.title(l10n),
                          style: ui.text.headline,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    next == null
                        ? progress
                        : l10n.achievementProgressSummary(
                            progress: progress,
                            gold: next.goldAmount,
                          ),
                    style: ui.text.body.copyWith(
                      color: next == null
                          ? ui.colors.success
                          : ui.colors.textPrimary,
                    ),
                  ),
                ],
              );
              if (entry.claimableGold == 0) return summary;
              final claim = AchievementClaimAction(
                key: ValueKey('claim-${entry.id}'),
                gold: entry.claimableGold,
                onPressed: claiming ? null : onClaim,
              );
              // At larger text sizes, reserve enough reading width for the
              // summary before keeping the action on the same line.
              if (constraints.maxWidth >=
                  MediaQuery.textScalerOf(context).scale(320)) {
                return Row(
                  children: [
                    Expanded(child: summary),
                    SizedBox(width: ui.space.sm),
                    claim,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  SizedBox(height: ui.space.xxs),
                  Align(alignment: Alignment.centerRight, child: claim),
                ],
              );
            },
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: ui.space.xs),
            child: LinearProgressIndicator(
              value: next == null
                  ? 1
                  : (entry.value / next.threshold).clamp(0, 1),
              minHeight: ui.space.xxs,
              color: ui.colors.accentStrong,
              backgroundColor: ui.colors.background,
              borderRadius: BorderRadius.circular(ui.radii.sm),
              semanticsLabel: requirement,
            ),
          ),
          children: [
            AchievementTierLedger(
              key: ValueKey('achievement-ledger-${entry.id}'),
              entry: entry,
              presentation: presentation,
            ),
            ExpansionTile(
              key: PageStorageKey('achievement-rules-${entry.id}'),
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.only(bottom: ui.space.xs),
              minTileHeight: ui.sizes.tapTarget,
              dense: true,
              title: Text(
                l10n.achievementWhatCounts,
                style: ui.text.body.copyWith(color: ui.colors.textMuted),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(requirement, style: ui.text.body),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    presentation.eligibility(l10n),
                    style: ui.text.body.copyWith(color: ui.colors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
