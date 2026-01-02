import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Applies `SystemChrome.setEnabledSystemUIMode` while this widget is mounted.
///
/// Scoped to a subtree (typically a route) so embedding stays clean.
class ScopedSystemUiMode extends StatefulWidget {
  const ScopedSystemUiMode({
    super.key,
    required this.mode,
    required this.child,
    this.overlays,
    this.restoreMode = SystemUiMode.edgeToEdge,
    this.restoreOverlays,
  });

  final SystemUiMode mode;
  final List<SystemUiOverlay>? overlays;

  final SystemUiMode restoreMode;
  final List<SystemUiOverlay>? restoreOverlays;

  final Widget child;

  @override
  State<ScopedSystemUiMode> createState() => _ScopedSystemUiModeState();
}

class _ScopedSystemUiModeState extends State<ScopedSystemUiMode> {
  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant ScopedSystemUiMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.overlays != widget.overlays) {
      _apply();
    }
  }

  void _apply() {
    SystemChrome.setEnabledSystemUIMode(widget.mode, overlays: widget.overlays);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      widget.restoreMode,
      overlays: widget.restoreOverlays,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
