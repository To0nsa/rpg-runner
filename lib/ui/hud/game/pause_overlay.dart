import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../theme/ui_tokens.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.visible,
    required this.exitConfirmOpen,
    required this.onResume,
    required this.onExit,
  });

  final bool visible;
  final bool exitConfirmOpen;
  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final ui = context.ui;

    return SizedBox.expand(
      child: ColoredBox(
        color: ui.colors.shadow.withValues(alpha: 0.4),
        child: SafeArea(
          minimum: EdgeInsets.all(ui.space.md),
          child: Center(
            child: exitConfirmOpen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Want to exit?',
                        style: ui.text.title.copyWith(
                          color: ui.colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: ui.space.sm + ui.space.xxs / 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: 'Resume',
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.xs,
                            onPressed: onResume,
                          ),
                          SizedBox(width: ui.space.sm),
                          AppButton(
                            label: 'Exit',
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.xs,
                            onPressed: onExit,
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
