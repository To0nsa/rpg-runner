import 'package:flutter/material.dart';

import '../theme/ui_resource_colors.dart';
import 'control_resource_usage.dart';

/// Explains a resource-blocked touch without forwarding an action or hold edge.
/// The caller excludes invalid slots and cooldown-only failures.
class ResourceActionFeedback extends StatefulWidget {
  const ResourceActionFeedback({
    super.key,
    required this.missing,
    required this.child,
    this.onShortfall,
  });

  final ControlResourceUsage missing;
  final ValueChanged<ControlResourceUsage>? onShortfall;
  final Widget child;

  @override
  State<ResourceActionFeedback> createState() => _ResourceActionFeedbackState();
}

class _ResourceActionFeedbackState extends State<ResourceActionFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _warning;
  ControlResourceUsage _missing = ControlResourceUsage.none;

  @override
  void initState() {
    super.initState();
    _warning = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      // Reduced motion retains a static warning for the same readable duration.
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void dispose() {
    _warning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Listener(
      behavior: widget.missing.isEmpty
          ? HitTestBehavior.deferToChild
          : HitTestBehavior.opaque,
      onPointerDown: widget.missing.isEmpty
          ? null
          : (_) {
              _missing = widget.missing;
              _warning.forward(from: 0);
              widget.onShortfall?.call(_missing);
            },
      child: AnimatedBuilder(
        animation: _warning,
        child: widget.child,
        builder: (context, child) => Stack(
          children: [
            child!,
            if (_warning.isAnimating)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: reduceMotion ? 1 : 1 - _warning.value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 2,
                          color: _missing.health
                              ? UiResourceColors.health
                              : _missing.mana
                              ? UiResourceColors.mana
                              : UiResourceColors.stamina,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
