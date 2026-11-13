import 'package:flutter/material.dart';

import '../../l10n/app_localization.dart';
import '../../state/ownership/achievement_progress.dart';
import '../../theme/ui_tokens.dart';
import 'achievement_presentation.dart';

/// Aligns tier facts across rows; narrow or enlarged text keeps each target
/// beside its reward/history instead of squeezing four columns.
class AchievementTierLedger extends StatelessWidget {
  const AchievementTierLedger({
    super.key,
    required this.entry,
    required this.presentation,
  });

  final AchievementEntry entry;
  final AchievementPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final l10n = context.l10n;
    final names = [l10n.uiBronze, l10n.uiSilver, l10n.uiGold];
    final muted = ui.text.body.copyWith(color: ui.colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= MediaQuery.textScalerOf(context).scale(480);
        Widget cell(Widget child) => Padding(
          padding: EdgeInsets.symmetric(
            vertical: wide ? ui.space.xxs : ui.space.xs,
            horizontal: ui.space.xxs,
          ),
          child: child,
        );

        return Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder(
            horizontalInside: BorderSide(color: ui.colors.outline),
          ),
          columnWidths: wide
              ? const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                  2: IntrinsicColumnWidth(),
                  3: FlexColumnWidth(1.3),
                }
              : const {0: FlexColumnWidth(), 1: FlexColumnWidth(1.4)},
          children: [
            for (var index = 0; index < entry.tiers.length; index += 1)
              _buildRow(context, index, names[index], wide, muted, cell),
          ],
        );
      },
    );
  }

  TableRow _buildRow(
    BuildContext context,
    int index,
    String name,
    bool wide,
    TextStyle muted,
    Widget Function(Widget) cell,
  ) {
    final tier = entry.tiers[index];
    final ui = context.ui;
    final l10n = context.l10n;
    final state = tier.claimedAtMs != null
        ? 'claimed'
        : tier.achieved
        ? 'achieved'
        : tier.threshold == entry.nextTier?.threshold
        ? 'next'
        : 'locked';
    final nameWidget = Text(
      name,
      style: ui.text.body.copyWith(fontWeight: FontWeight.w600),
    );
    final target = Text(
      presentation.quantity(tier.threshold, l10n),
      style: ui.text.body,
    );
    final history = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          wide
              ? l10n.achievementTierStatus(state: state)
              : l10n.achievementTierReward(gold: tier.goldAmount, state: state),
          style: tier.canClaim
              ? ui.text.body.copyWith(color: ui.colors.accentStrong)
              : ui.text.body,
          textAlign: TextAlign.end,
        ),
        if (tier.achievedAtMs case final achievedAt?)
          Text(
            achievementDate(achievedAt, l10n),
            semanticsLabel: l10n.achievementAchievedDate(
              date: achievementDate(achievedAt, l10n),
            ),
            style: muted,
            textAlign: TextAlign.end,
          ),
      ],
    );
    return TableRow(
      children: wide
          ? [
              cell(nameWidget),
              cell(target),
              cell(
                Text(
                  l10n.goldAmount(gold: tier.goldAmount),
                  style: ui.text.body,
                ),
              ),
              cell(history),
            ]
          : [
              cell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [nameWidget, target],
                ),
              ),
              cell(history),
            ],
    );
  }
}
