import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class EditorSceneViewportFrame extends StatelessWidget {
  const EditorSceneViewportFrame({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.overlayColor = const ui.Color.fromARGB(255, 101, 171, 211),
  });

  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color overlayColor;

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
            IgnorePointer(
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
