import 'package:rpg_runner/ui/l10n/app_localization.dart';
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
    this.messagesNeedAttention = false,
  });

  final VoidCallback? onTownPressed;
  final VoidCallback? onProfilePressed;
  final VoidCallback? onLeaderboardsPressed;
  final VoidCallback? onMessagesPressed;
  final bool messagesNeedAttention;
  final VoidCallback onOptionsPressed;

  @override
  Widget build(BuildContext context) {
    final actions = <MenuIconAction>[
      MenuIconAction(
        icon: Icons.castle,
        tooltip: context.l10n.uiTown,
        onPressed: onTownPressed,
      ),
      MenuIconAction(
        icon: Icons.person,
        tooltip: context.l10n.uiProfile,
        onPressed: onProfilePressed,
      ),
      MenuIconAction(
        icon: Icons.leaderboard,
        tooltip: context.l10n.uiTop,
        onPressed: onLeaderboardsPressed,
      ),
      MenuIconAction(
        icon: Icons.message,
        tooltip: context.l10n.uiMessages,
        needsAttention: messagesNeedAttention,
        attentionLabel: context.l10n.uiUnreadMessagesOrUnclaimedGifts,
        onPressed: onMessagesPressed,
      ),
      MenuIconAction(
        icon: Icons.settings,
        tooltip: context.l10n.uiOptions,
        onPressed: onOptionsPressed,
      ),
    ];

    return MenuIconColumn(actions: actions);
  }
}
