import 'package:flutter/material.dart';

import 'menu_button.dart';

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Weekly Challenge · Coming Soon',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          MenuButton(
            label: 'Play',
            width: 100,
            height: 36,
            fontSize: 12,
            onPressed: onWeeklyPressed,
          ),
          const SizedBox(width: 8),
          MenuButton(
            label: 'Leaderboard',
            width: 120,
            height: 36,
            fontSize: 12,
            onPressed: onWeeklyLeaderboardPressed,
          ),
        ],
      ),
    );
  }
}
