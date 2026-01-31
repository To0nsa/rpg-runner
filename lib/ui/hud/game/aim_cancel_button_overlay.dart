import 'package:flutter/material.dart';

import '../../../game/input/aim_preview.dart';

/// Visual-only cancel affordance for aimed actions.
///
/// Important: this widget does *not* receive pointer events when the player
/// started the gesture on an action button (hit testing is frozen on pointer
/// down). The action buttons must hit-test this widget's global rect on release.
class AimCancelButtonOverlay extends StatefulWidget {
  const AimCancelButtonOverlay({
    super.key,
    required this.projectileAimPreview,
    required this.meleeAimPreview,
    required this.hitboxRect,
  });

  final AimPreviewModel projectileAimPreview;
  final AimPreviewModel meleeAimPreview;

  /// Global rect (screen space) of the cancel hitbox.
  ///
  /// Directional buttons read this on pointer-up to decide whether to cancel.
  final ValueNotifier<Rect?> hitboxRect;

  @override
  State<AimCancelButtonOverlay> createState() => _AimCancelButtonOverlayState();
}

class _AimCancelButtonOverlayState extends State<AimCancelButtonOverlay> {
  final GlobalKey _hitboxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.projectileAimPreview.addListener(_onAimChanged);
    widget.meleeAimPreview.addListener(_onAimChanged);
    _onAimChanged();
  }

  @override
  void didUpdateWidget(covariant AimCancelButtonOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectileAimPreview != widget.projectileAimPreview) {
      oldWidget.projectileAimPreview.removeListener(_onAimChanged);
      widget.projectileAimPreview.addListener(_onAimChanged);
    }
    if (oldWidget.meleeAimPreview != widget.meleeAimPreview) {
      oldWidget.meleeAimPreview.removeListener(_onAimChanged);
      widget.meleeAimPreview.addListener(_onAimChanged);
    }
    if (oldWidget.hitboxRect != widget.hitboxRect) {
      // Force recompute if the target notifier changed.
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncHitboxRect());
    }
    _onAimChanged();
  }

  @override
  void dispose() {
    widget.projectileAimPreview.removeListener(_onAimChanged);
    widget.meleeAimPreview.removeListener(_onAimChanged);
    widget.hitboxRect.value = null;
    super.dispose();
  }

  bool get _active =>
      widget.projectileAimPreview.value.active || widget.meleeAimPreview.value.active;

  void _onAimChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHitboxRect());
  }

  void _syncHitboxRect() {
    if (!mounted) return;

    if (!_active) {
      if (widget.hitboxRect.value != null) {
        widget.hitboxRect.value = null;
      }
      return;
    }

    final ctx = _hitboxKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;

    final topLeft = ro.localToGlobal(Offset.zero);
    final rect = topLeft & ro.size;

    if (widget.hitboxRect.value != rect) {
      widget.hitboxRect.value = rect;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();

    // Fixed screen-space location between clock (top-center) and distance (top-right).
    // The hitbox is intentionally larger than the icon for mobile ergonomics.
    return Positioned(
      top: 56,
      right: 180,
      child: IgnorePointer(
        // Visual only; directional buttons do the hit-test in screen space.
        ignoring: true,
        child: SizedBox(
          key: _hitboxKey,
          width: 56,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color.fromARGB(26, 255, 0, 0),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Center(
              child: Icon(
                Icons.close,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
