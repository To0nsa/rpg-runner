import 'package:flutter/widgets.dart';

import 'viewport_metrics.dart';

/// Scales a fixed virtual canvas into the available space.
///
/// Use [computeViewportMetrics] so rendering and input mapping share the same
/// view size + offset.
class GameViewport extends StatelessWidget {
  const GameViewport({
    super.key,
    required this.metrics,
    required this.child,
    this.letterboxColor = const Color(0xFF000000),
  });

  final ViewportMetrics metrics;
  final Widget child;
  final Color letterboxColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: letterboxColor,
      child: ClipRect(
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: metrics.offsetX,
                top: metrics.offsetY,
                width: metrics.viewW,
                height: metrics.viewH,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
