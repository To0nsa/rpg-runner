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
    final scrim = unselected
        ? UiBrandPalette.unselectedCardScrim
        : levelId == LevelId.field
        ? UiBrandPalette.black.withValues(alpha: 0.45)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        LevelParallaxPreview(
          visualThemeId: levelId.visualThemeId,
          alignment: Alignment.center,
        ),
        if (scrim != null) ColoredBox(color: scrim),
      ],
    );
  }
}
