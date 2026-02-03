import 'package:flutter/material.dart';

import 'menu_button.dart';
import '../theme/ui_tokens.dart';

class WeeklyBadgeRow extends StatelessWidget {
  const WeeklyBadgeRow({
    super.key,
    required this.onWeeklyPressed,
    required this.onWeeklyLeaderboardPressed,
  });

  final VoidCallback? onWeeklyPressed;
  final VoidCallback onWeeklyLeaderboardPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ui.space.xs,
        vertical: ui.space.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: ui.colors.outline,
          width: ui.sizes.borderWidth,
        ),
        borderRadius: BorderRadius.circular(ui.radii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Weekly Challenge · Coming Soon',
              style: ui.text.body.copyWith(color: ui.colors.textMuted),
            ),
          ),
          MenuButton(
            label: 'Play',
            width: ui.sizes.weeklyButtonWidth,
            height: ui.sizes.buttonHeight,
            fontSize: ui.text.label.fontSize ?? 12,
            backgroundColor: ui.colors.buttonBg,
            foregroundColor: ui.colors.buttonFg,
            borderColor: ui.colors.buttonBorder,
            borderWidth: ui.sizes.borderWidth,
            onPressed: onWeeklyPressed,
          ),
          SizedBox(width: ui.space.xs),
          MenuButton(
            label: 'Leaderboard',
            width: ui.sizes.leaderboardButtonWidth,
            height: ui.sizes.buttonHeight,
            fontSize: ui.text.label.fontSize ?? 12,
            backgroundColor: ui.colors.buttonBg,
            foregroundColor: ui.colors.buttonFg,
            borderColor: ui.colors.buttonBorder,
            borderWidth: ui.sizes.borderWidth,
            onPressed: onWeeklyLeaderboardPressed,
          ),
        ],
      ),
    );
  }
}
