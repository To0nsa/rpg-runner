import 'package:flutter/material.dart';

import '../state/ownership/player_progress.dart';
import '../theme/ui_tokens.dart';

/// Account level and progress toward the next level, derived from lifetime XP.
class PlayerLevelBar extends StatelessWidget {
  const PlayerLevelBar({super.key, required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final earned = progress.xpInLevel;
    final needed = progress.xpForNextLevel;
    return Semantics(
      label: 'Level ${progress.level}, $earned of $needed XP to next level',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(ui.radii.sm),
              child: SizedBox(
                height: 28,
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    ColoredBox(color: ui.colors.outline),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: earned / needed,
                        heightFactor: 1,
                        child: ColoredBox(color: ui.colors.accentStrong),
                      ),
                    ),
                    ColoredBox(
                      color: ui.colors.background.withValues(alpha: .35),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: ui.space.xxs),
                        child: Text(
                          'LEVEL ${progress.level}  ·  $earned / $needed XP',
                          style: ui.text.label.copyWith(
                            color: ui.colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
