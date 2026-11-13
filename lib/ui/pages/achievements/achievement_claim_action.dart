import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';

import '../../components/app_button.dart';

/// Amount and gameplay coin stay inside the action, independently of expansion.
class AchievementClaimAction extends StatelessWidget {
  const AchievementClaimAction({
    super.key,
    required this.gold,
    required this.onPressed,
    this.all = false,
  });
  final int gold;
  final VoidCallback? onPressed;
  final bool all;

  @override
  Widget build(BuildContext context) => AppButton.gold(
    label: context.l10n.achievementClaimAmount(
      gold: gold,
      scope: all ? 'all' : 'single',
    ),
    semanticLabel: context.l10n.achievementClaimGoldLabel(
      gold: gold,
      scope: all ? 'all' : 'single',
    ),
    size: all ? AppButtonSize.sm : AppButtonSize.xxs,
    onPressed: onPressed,
  );
}
