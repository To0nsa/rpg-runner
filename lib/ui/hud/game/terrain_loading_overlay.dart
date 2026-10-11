import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../components/app_button.dart';
import '../../theme/ui_tokens.dart';

/// Runtime recovery stays separate from startup loading and gameplay pause.
class TerrainLoadingOverlay extends StatelessWidget {
  const TerrainLoadingOverlay({
    super.key,
    required this.readiness,
    required this.onRetry,
    this.onExit,
  });

  final TerrainReadiness readiness;
  final VoidCallback onRetry;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    if (readiness == TerrainReadiness.ready) return const SizedBox.shrink();
    final ui = context.ui;
    if (readiness == TerrainReadiness.preparing) {
      // Controls remain mounted and receive hold releases during a short wait.
      return IgnorePointer(
        child: Align(
          alignment: const Alignment(0, 0.55),
          child: Semantics(
            liveRegion: true,
            child: Text(
              'Preparing the path…',
              style: ui.text.body.copyWith(
                color: ui.colors.textPrimary,
                shadows: [Shadow(color: ui.colors.shadow, blurRadius: 4)],
              ),
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          color: ui.colors.shadow.withValues(alpha: 0.7),
          dismissible: false,
        ),
        SafeArea(
          minimum: EdgeInsets.all(ui.space.md),
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to prepare the path',
                    style: ui.text.title.copyWith(color: ui.colors.textPrimary),
                  ),
                  SizedBox(height: ui.space.sm),
                  Text(
                    'Your run is held here. Retry to continue.',
                    style: ui.text.body.copyWith(color: ui.colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ui.space.md),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        label: 'Retry',
                        size: AppButtonSize.xs,
                        onPressed: onRetry,
                      ),
                      if (onExit != null) ...[
                        SizedBox(width: ui.space.sm),
                        AppButton(
                          label: 'Exit',
                          size: AppButtonSize.xs,
                          variant: AppButtonVariant.secondary,
                          onPressed: onExit,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
