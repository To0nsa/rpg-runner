import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../l10n/app_localization.dart';
import '../theme/ui_tokens.dart';

/// Objective counts and the exit direction come only from the Core snapshot.
class CampaignHud extends StatelessWidget {
  const CampaignHud({super.key, required this.controller});
  final GameController controller;
  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final campaign = snapshot.campaign;
    if (campaign == null) return const SizedBox.shrink();
    final playerX = snapshot.playerEntity?.pos.x ?? campaign.exitX;
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.campaignObjectives(
                completed: campaign.completed,
                required: campaign.required,
              ),
              style: context.ui.text.body,
              textAlign: TextAlign.center,
            ),
            if (campaign.exitReady)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    campaign.exitX >= playerX
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                    size: 16,
                  ),
                  Flexible(
                    child: Text(
                      context.l10n.campaignReachExit,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
