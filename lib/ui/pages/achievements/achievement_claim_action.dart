import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../theme/ui_tokens.dart';

/// Wrap the amount beside an action that can grow with translations and text scale.
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
  Widget build(BuildContext context) => Wrap(
    spacing: context.ui.space.sm,
    runSpacing: context.ui.space.xxs,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      AppButton(
        label: all ? context.l10n.uiClaimAll : context.l10n.uiClaim,
        size: all ? AppButtonSize.sm : AppButtonSize.xxs,
        onPressed: onPressed,
      ),
      Text(context.l10n.goldAmount(gold: gold), style: context.ui.text.body),
    ],
  );
}
