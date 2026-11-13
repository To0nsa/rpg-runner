import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';
import 'package:game_presentation/gold_coin.dart';

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
            ? context.l10n.uiYourGoldIsReady
            : verifying
            ? context.l10n.uiYourRewardsAreOnTheirWay
            : context.l10n.uiYourBalanceHasChanged,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ready)
              Icon(
                Icons.check_circle_outline,
                color: ui.colors.accentStrong,
                size: ui.sizes.iconSize.lg,
              )
            else
              GoldCoin(size: ui.sizes.iconSize.lg),
            SizedBox(height: ui.space.sm),
            Text(
              ready
                  ? context
                        .l10n
                        .uiYourRunRewardsAreConfirmedYouCanNowSpendYourGold
                  : verifying
                  ? context
                        .l10n
                        .uiWeReConfirmingYourLatestRunRewardsBeforeTheyCanBeSpentYouCanKeepPlayingWhileWeFinish
                  : context
                        .l10n
                        .uiThereIsnTEnoughGoldForThisPurchaseReturnToTheStoreToSeeYourUpdatedBalance,
              style: ui.text.body.copyWith(color: ui.colors.textPrimary),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: ready || !verifying
                ? context.l10n.uiBackToStore
                : context.l10n.uiGotIt,
            size: AppButtonSize.sm,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}
