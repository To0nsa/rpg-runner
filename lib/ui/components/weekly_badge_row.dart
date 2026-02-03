import 'package:flutter/material.dart';

import 'app_button.dart';
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
            child: Text('Weekly Challenge · Coming Soon', style: ui.text.body),
          ),
          AppButton(
            label: 'Play',
            width: ui.sizes.weeklyButtonWidth,
            onPressed: onWeeklyPressed,
          ),
          SizedBox(width: ui.space.xs),
          AppButton(
            label: 'Leaderboard',
            width: ui.sizes.leaderboardButtonWidth,
            onPressed: onWeeklyLeaderboardPressed,
          ),
        ],
      ),
    );
  }
}
