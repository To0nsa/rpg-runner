import 'package:flutter/material.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Game Over',
          style: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitleDeathReason != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitleDeathReason!,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (displayScore != null) ...[
          const SizedBox(height: 14),
          Text(
            'Score: $displayScore',
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
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
