import 'package:flutter/material.dart';

import '../../../core/levels/level_id.dart';
import '../../levels/level_id_ui.dart';
import '../../components/level_parallax_preview.dart';

/// A card widget displaying a level with its full parallax background.
///
/// Shows all parallax layers composited as background with the title centered.
/// Use in a row for level selection screens.
class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.levelId,
    required this.onTap,
    this.selected = false,
    this.width,
    this.height = 120,
    this.borderRadius = 12,
  });

  /// The level this card represents.
  final LevelId levelId;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

  /// Whether this card is currently selected.
  final bool selected;

  /// Card width. If null, uses available space (e.g., in Expanded).
  final double? width;

  /// Card height. Defaults to 120.
  final double height;

  /// Corner radius. Defaults to 12.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: selected ? Colors.amberAccent : Colors.white,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full theme preview (no gradient overlay).
              LevelParallaxPreview(themeId: levelId.themeId),

              // Title: readable via shadow, not via a dark scrim.
              Center(
                child: Text(
                  levelId.displayName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
