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
    final actions = <_HubMenuAction>[
      _HubMenuAction(
        icon: Icons.storefront,
        tooltip: 'Town',
        onPressed: onTownPressed,
      ),
      _HubMenuAction(
        icon: Icons.person,
        tooltip: 'Profile',
        onPressed: onProfilePressed,
      ),
      _HubMenuAction(
        icon: Icons.leaderboard,
        tooltip: 'Top',
        onPressed: onLeaderboardsPressed,
      ),
      _HubMenuAction(
        icon: Icons.message,
        tooltip: 'Messages',
        onPressed: onMessagesPressed,
      ),
      _HubMenuAction(
        icon: Icons.settings,
        tooltip: 'Options',
        onPressed: onOptionsPressed,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final action in actions)
          AppIconButton(
            icon: action.icon,
            tooltip: action.tooltip,
            onPressed: action.onPressed,
          ),
      ],
    );
  }
}

class _HubMenuAction {
  const _HubMenuAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}
