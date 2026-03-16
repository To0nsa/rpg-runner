import 'package:flutter/material.dart';

import '../../../components/app_button.dart';
import '../../../components/play_button.dart';
import '../../../theme/ui_tokens.dart';

class WeeklyBadgeRow extends StatelessWidget {
  const WeeklyBadgeRow({
    super.key,
    required this.title,
    required this.isWeeklyLoading,
    required this.onWeeklyPressed,
    required this.onWeeklyLeaderboardPressed,
  });

  final String title;
  final bool isWeeklyLoading;
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
              title,
              style: ui.text.body,
              textAlign: TextAlign.center,
            ),
          ),
          PlayButton(
            isLoading: isWeeklyLoading,
            onPressed: onWeeklyPressed,
            size: AppButtonSize.xxs,
            loadingIndicatorSize: ui.sizes.iconSize.sm,
          ),
          SizedBox(width: ui.space.xs),
          AppButton(
            label: 'Leaderboard',
            size: AppButtonSize.sm,
            onPressed: onWeeklyLeaderboardPressed,
          ),
        ],
      ),
    );
  }
}
