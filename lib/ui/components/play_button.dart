import 'package:flutter/material.dart';

import 'app_button.dart';
import '../theme/ui_tokens.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Stack(
      alignment: Alignment.center,
      children: [
        AppButton(
          label: 'PLAY',
          size: AppButtonSize.lg,
          onPressed: isLoading ? null : onPressed,
        ),
        if (isLoading)
          SizedBox(
            width: ui.sizes.iconSize.md,
            height: ui.sizes.iconSize.md,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ui.colors.textPrimary),
            ),
          ),
      ],
    );
  }
}
