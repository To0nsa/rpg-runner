import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../theme/ui_tokens.dart';

/// Keep the amount outside the fixed-size button so enlarged text cannot hide it.
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
        label: all ? 'Claim all' : 'Claim',
        size: all ? AppButtonSize.sm : AppButtonSize.xxs,
        onPressed: onPressed,
      ),
      Text('$gold gold', style: context.ui.text.body),
    ],
  );
}
