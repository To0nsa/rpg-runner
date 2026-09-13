import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A visual-only 60Hz preview clock, active only for animated material content.
/// Authored Play uses Core ticks instead; this clock never drives simulation.
class TerrainAnimationPreview extends StatefulWidget {
  const TerrainAnimationPreview({
    super.key,
    required this.enabled,
    required this.builder,
  });
  final bool enabled;
  final Widget Function(int tick) builder;
  @override
  State<TerrainAnimationPreview> createState() =>
      _TerrainAnimationPreviewState();
}

class _TerrainAnimationPreviewState extends State<TerrainAnimationPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final tick =
          elapsed.inMicroseconds * 60 ~/ Duration.microsecondsPerSecond;
      if (tick != _tick) setState(() => _tick = tick);
    });
    if (widget.enabled) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant TerrainAnimationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ticker.isActive) _ticker.start();
    if (!widget.enabled && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_tick);
}
