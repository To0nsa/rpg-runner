import 'package:flutter/material.dart';

import '../../../components/app_button.dart';

enum HubCardActionVariant { play, change }

/// Uses the game-button treatment within the owning card's rounded clip.
class HubCardAction extends StatelessWidget {
  const HubCardAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = HubCardActionVariant.play,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final HubCardActionVariant variant;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppButton.cardFooter(
      label: label,
      onPressed: isLoading ? null : onPressed,
      variant: variant == HubCardActionVariant.play
          ? AppButtonVariant.primary
          : AppButtonVariant.secondary,
    );
  }
}
