import 'package:flutter/material.dart';
import 'package:runner_core/levels/level_id.dart';

import '../levels/level_id_ui.dart';
import '../theme/ui_tokens.dart';
import 'level_parallax_preview.dart';

/// Level artwork with enough contrast for the card title over bright themes.
class LevelCardArtwork extends StatelessWidget {
  const LevelCardArtwork({
    super.key,
    required this.levelId,
    this.unselected = false,
  });

  final LevelId levelId;
  final bool unselected;

  @override
  Widget build(BuildContext context) {
    final scrimOpacity = unselected
        ? 0.60
        : levelId == LevelId.field
        ? 0.45
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        LevelParallaxPreview(
          visualThemeId: levelId.visualThemeId,
          alignment: Alignment.center,
        ),
        if (scrimOpacity > 0)
          ColoredBox(
            color: UiBrandPalette.black.withValues(alpha: scrimOpacity),
          ),
      ],
    );
  }
}
