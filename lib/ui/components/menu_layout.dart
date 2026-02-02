import 'dart:math' as math;

import 'package:flutter/material.dart';

class MenuLayout extends StatelessWidget {
  const MenuLayout({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.horizontalPadding = 24,
    this.verticalPadding = 0,
    this.scrollable = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final bool scrollable;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        );
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - padding.horizontal,
        );
        final width = math.min(availableWidth, maxWidth);

        final aligned = Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: child,
            ),
          ),
        );

        if (!scrollable) {
          return aligned;
        }

        final minHeight = math.max(
          0.0,
          constraints.maxHeight - padding.vertical,
        );

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: aligned,
          ),
        );
      },
    );
  }
}
