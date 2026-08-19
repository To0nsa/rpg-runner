import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Standard chrome wrapper for scene viewport content.
///
/// Provides consistent clipping and an optional border overlay while leaving
/// input and render behavior fully owned by the child scene widget tree.
class EditorSceneViewportFrame extends StatelessWidget {
  const EditorSceneViewportFrame({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.overlayColor = const ui.Color.fromARGB(255, 101, 171, 211),
    this.showBorder = true,
  });

  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color overlayColor;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (showBorder)
              IgnorePointer(
                // Border overlay is decorative only; pointer events must pass
                // through to scene interaction layers.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: overlayColor, width: 1),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
