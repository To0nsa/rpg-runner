import 'package:flutter/material.dart';

import '../../../game/game_controller.dart';
import '../../theme/ui_tokens.dart';
import '../../components/hud_frame.dart';
import '../../theme/ui_hud_theme.dart';
import 'score_overlay.dart';

class TopRightHudOverlay extends StatelessWidget {
  const TopRightHudOverlay({
    super.key,
    required this.controller,
    required this.showExitButton,
    required this.onExit,
  });

  final GameController controller;
  final bool showExitButton;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.all(ui.space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreOverlay(controller: controller),
            if (showExitButton) ...[
              SizedBox(width: ui.space.xs),
              HudPanel(
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                  onPressed: onExit,
                  icon: const Icon(Icons.close),
                  color: context.hudTheme.foreground,
                  disabledColor: ui.colors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
