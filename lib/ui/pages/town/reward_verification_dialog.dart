import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../components/app_dialog.dart';
import '../../state/app/app_state.dart';
import '../../theme/ui_tokens.dart';

/// Explains why a displayed balance cannot yet fund a purchase. The dialog
/// observes settlement, but never submits or retries a purchase on its own.
class RewardVerificationDialog extends StatelessWidget {
  const RewardVerificationDialog({
    super.key,
    required this.appState,
    required this.cost,
  });

  final AppState appState;
  final int cost;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appState,
    builder: (context, _) {
      final ui = context.ui;
      final ready = appState.progression.gold >= cost;
      final verifying = appState.goldNeedsVerification(cost);
      return AppDialog(
        title: ready
            ? 'Your gold is ready'
            : verifying
            ? 'Your rewards are on their way'
            : 'Your balance has changed',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.savings_outlined,
              color: ui.colors.accentStrong,
              size: ui.sizes.iconSize.lg,
            ),
            SizedBox(height: ui.space.sm),
            Text(
              ready
                  ? 'Your run rewards are confirmed. You can now spend your gold.'
                  : verifying
                  ? 'We’re confirming your latest run rewards before they can '
                        'be spent. You can keep playing while we finish.'
                  : 'There isn’t enough gold for this purchase. '
                        'Return to the store to see your updated balance.',
              style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: ready || !verifying ? 'Back to store' : 'Got it',
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
