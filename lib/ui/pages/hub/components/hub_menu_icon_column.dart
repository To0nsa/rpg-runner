import 'package:flutter/material.dart';

import '../../../components/menu_icon_column.dart';

/// Hub navigation icon column shown on the left side of the play hub.
class HubMenuIconColumn extends StatelessWidget {
  const HubMenuIconColumn({
    super.key,
    required this.onTownPressed,
    required this.onProfilePressed,
    required this.onLeaderboardsPressed,
    required this.onMessagesPressed,
    required this.onOptionsPressed,
  });

  final VoidCallback? onTownPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onLeaderboardsPressed;
  final VoidCallback onMessagesPressed;
  final VoidCallback onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    final actions = <MenuIconAction>[
      MenuIconAction(
        icon: Icons.storefront,
        tooltip: 'Town',
        onPressed: onTownPressed,
      ),
      MenuIconAction(
        icon: Icons.person,
        tooltip: 'Profile',
        onPressed: onProfilePressed,
      ),
      MenuIconAction(
        icon: Icons.leaderboard,
        tooltip: 'Top',
        onPressed: onLeaderboardsPressed,
      ),
      MenuIconAction(
        icon: Icons.message,
        tooltip: 'Messages',
        onPressed: onMessagesPressed,
      ),
      MenuIconAction(
        icon: Icons.settings,
        tooltip: 'Options',
        onPressed: onOptionsPressed,
      ),
    ];

    return MenuIconColumn(actions: actions);
  }
}
