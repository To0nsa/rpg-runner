import 'package:flutter/material.dart';

import 'app_button.dart';
import '../theme/ui_tokens.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    this.size = AppButtonSize.lg,
    this.loadingIndicatorSize,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final AppButtonSize size;
  final double? loadingIndicatorSize;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Stack(
      alignment: Alignment.center,
      children: [
        AppButton(
          label: 'PLAY',
          size: size,
          onPressed: isLoading ? null : onPressed,
        ),
        if (isLoading)
          SizedBox(
            width: loadingIndicatorSize ?? ui.sizes.iconSize.md,
            height: loadingIndicatorSize ?? ui.sizes.iconSize.md,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ui.colors.textPrimary),
            ),
          ),
      ],
    );
  }
}
