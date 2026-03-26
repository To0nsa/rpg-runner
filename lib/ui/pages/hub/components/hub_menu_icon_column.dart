import 'package:flutter/material.dart';

import '../../../components/app_icon_button.dart';

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

  final VoidCallback onTownPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback onLeaderboardsPressed;
  final VoidCallback onMessagesPressed;
  final VoidCallback onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIconButton(
          icon: Icons.storefront,
          tooltip: 'Town',
          onPressed: onTownPressed,
        ),
        AppIconButton(
          icon: Icons.person,
          tooltip: 'Profile',
          onPressed: onProfilePressed,
        ),
        AppIconButton(
          icon: Icons.leaderboard,
          tooltip: 'Top',
          onPressed: onLeaderboardsPressed,
        ),
        AppIconButton(
          icon: Icons.message,
          tooltip: 'Messages',
          onPressed: onMessagesPressed,
        ),
        AppIconButton(
          icon: Icons.settings,
          tooltip: 'Options',
          onPressed: onOptionsPressed,
        ),
      ],
    );
  }
}
