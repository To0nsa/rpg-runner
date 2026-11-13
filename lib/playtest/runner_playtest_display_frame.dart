import 'package:flutter/material.dart';

import 'runner_playtest_display.dart';

/// Fixed-size layout for the complete game/HUD. Scale is resolved by the caller,
/// never inferred from available space. Scrollbars reveal overflow without
/// consuming joystick or aim drags. A null display preserves normal embedding.
class RunnerPlaytestDisplayFrame extends StatefulWidget {
  const RunnerPlaytestDisplayFrame({
    super.key,
    required this.display,
    required this.child,
    this.scale = 1,
    this.previewKey,
    this.onGeometryChanged,
  }) : assert(scale > 0);
  final RunnerPlaytestDisplay? display;
  final Widget child;
  final double scale;
  final GlobalKey? previewKey;
  final VoidCallback? onGeometryChanged;
  @override
  State<RunnerPlaytestDisplayFrame> createState() =>
      _RunnerPlaytestDisplayFrameState();
}

class _RunnerPlaytestDisplayFrameState
    extends State<RunnerPlaytestDisplayFrame> {
  final _horizontal = ScrollController();
  final _vertical = ScrollController();
  Size? _available;
  bool _notificationPending = false;
  void _changed() {
    if (_notificationPending) return;
    _notificationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationPending = false;
      if (mounted) widget.onGeometryChanged?.call();
    });
  }

  @override
  void initState() {
    super.initState();
    _horizontal.addListener(_changed);
    _vertical.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant RunnerPlaytestDisplayFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.display != widget.display ||
        oldWidget.scale != widget.scale) {
      _changed();
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.display;
    if (target == null) return widget.child;
    return ColoredBox(
      color: const Color(0xFF05070A),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_available != null && _available != constraints.biggest) {
            _changed();
          }
          _available = constraints.biggest;
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(dragDevices: {}, scrollbars: false),
            child: Scrollbar(
              controller: _horizontal,
              thumbVisibility: true,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: Scrollbar(
                controller: _vertical,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: SingleChildScrollView(
                  controller: _vertical,
                  primary: false,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    primary: false,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: SizedBox(
                          key: widget.previewKey,
                          width: target.width * widget.scale,
                          height: target.height * widget.scale,
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: target.width.toDouble(),
                            maxWidth: target.width.toDouble(),
                            minHeight: target.height.toDouble(),
                            maxHeight: target.height.toDouble(),
                            child: Transform.scale(
                              scale: widget.scale,
                              alignment: Alignment.topLeft,
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  size: target.size,
                                  devicePixelRatio: target.devicePixelRatio,
                                  padding: EdgeInsets.zero,
                                  viewPadding: EdgeInsets.zero,
                                  viewInsets: EdgeInsets.zero,
                                  systemGestureInsets: EdgeInsets.zero,
                                  displayFeatures: const [],
                                ),
                                child: ClipRect(child: widget.child),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
