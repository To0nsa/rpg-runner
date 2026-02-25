import 'package:flutter/material.dart';

import '../../theme/ui_tokens.dart';

class GameOverHeader extends StatelessWidget {
  const GameOverHeader({
    super.key,
    required this.subtitleDeathReason,
    required this.displayScore,
  });

  final String? subtitleDeathReason;
  final int? displayScore;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Game Over',
          style: ui.text.title.copyWith(
            color: ui.colors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitleDeathReason != null) ...[
          SizedBox(height: ui.space.xs),
          Text(
            subtitleDeathReason!,
            style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
        if (displayScore != null) ...[
          SizedBox(height: ui.space.sm + ui.space.xxs / 2),
          Text(
            'Score: $displayScore',
            style: ui.text.headline.copyWith(
              color: ui.colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
