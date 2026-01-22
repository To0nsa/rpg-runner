import 'package:flutter/material.dart';

import '../../core/levels/level_id.dart';
import '../levels/level_id_ui.dart';

/// A card widget displaying a level with its parallax background.
///
/// Shows the level's preview image as background with the title centered.
/// Use in a row for level selection screens.
class LevelCard extends StatelessWidget {
  const LevelCard({
    super.key,
    required this.levelId,
    required this.onTap,
    this.width,
    this.height = 120,
    this.borderRadius = 12,
  });

  /// The level this card represents.
  final LevelId levelId;

  /// Callback when the card is tapped.
  final VoidCallback onTap;

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
          border: Border.all(color: Colors.white, width: 2),
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
              // Background image from parallax layer
              Image.asset(
                levelId.previewAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to solid color if image fails to load
                  return Container(color: Colors.grey[900]);
                },
              ),
              // Gradient overlay for text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              // Centered title
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
