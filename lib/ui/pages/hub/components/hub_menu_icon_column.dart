import 'package:flutter/material.dart';

import '../../../components/app_icon_button.dart';

/// Hub navigation icon column shown on the left side of the play hub.
class HubMenuIconColumn extends StatelessWidget {
  const HubMenuIconColumn({
    super.key,
    required this.onCodexPressed,
    required this.onTownPressed,
    required this.onProfilePressed,
    required this.onLeaderboardsPressed,
    required this.onMessagesPressed,
    required this.onSupportPressed,
    required this.onOptionsPressed,
  });

  final VoidCallback onCodexPressed;
  final VoidCallback onTownPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback onLeaderboardsPressed;
  final VoidCallback onMessagesPressed;
  final VoidCallback onSupportPressed;
  final VoidCallback onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.library_books,
              label: 'Codex',
              onPressed: onCodexPressed,
            ),
            AppIconButton(
              icon: Icons.storefront,
              label: 'Town',
              onPressed: onTownPressed,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.person,
              label: 'Profile',
              onPressed: onProfilePressed,
            ),
            AppIconButton(
              icon: Icons.leaderboard,
              label: 'Top',
              onPressed: onLeaderboardsPressed,
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              icon: Icons.message,
              label: 'Messages',
              onPressed: onMessagesPressed,
            ),
            AppIconButton(
              icon: Icons.monetization_on,
              label: 'Support',
              onPressed: onSupportPressed,
            ),
          ],
        ),
        AppIconButton(
          icon: Icons.settings,
          label: 'Options',
          onPressed: onOptionsPressed,
        ),
      ],
    );
  }
}
