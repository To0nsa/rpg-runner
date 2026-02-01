import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared frame for hub selection cards (level/character).
///
/// Owns layout contract: size, border, shadow, padding, clipping, and overlay.
class HubSelectionCardFrame extends StatelessWidget {
  const HubSelectionCardFrame({
    super.key,
    required this.width,
    required this.height,
    required this.background,
    required this.child,
    this.onTap,
    this.padding = defaultPadding,
    this.borderRadius = 12,
    this.borderColor = Colors.white54,
    this.borderWidth = 2,
    this.boxShadow = const [
      BoxShadow(
        color: Colors.black54,
        blurRadius: 8,
        offset: Offset(0, 4),
      ),
    ],
    this.overlayGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x00000000),
        Color(0xAA000000),
      ],
    ),
    this.backgroundColor = Colors.black,
  });

  static const double defaultWidth = 240;
  static const double defaultHeight = 128;
  static const EdgeInsets defaultPadding = EdgeInsets.all(16);

  final double width;
  final double height;
  final Widget background;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow> boxShadow;
  final Gradient? overlayGradient;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final innerRadius = math.max(0.0, borderRadius - borderWidth);

    final content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            if (overlayGradient != null)
              DecoratedBox(
                decoration: BoxDecoration(gradient: overlayGradient),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}
