import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';

/// Adds a themed attention dot without changing the child's layout or hit target.
/// The owning feature supplies visibility and accessible meaning; this component
/// stores no unread, discovery or reward state.
class AttentionMarker extends StatelessWidget {
  const AttentionMarker({
    super.key,
    required this.child,
    required this.visible,
    required this.semanticLabel,
  });
  final Widget child;
  final bool visible;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    return Semantics(
      value: visible ? semanticLabel : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (visible)
            PositionedDirectional(
              top: ui.space.xxs,
              end: ui.space.xxs,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Container(
                    width: ui.sizes.iconSize.xs,
                    height: ui.sizes.iconSize.xs,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ui.colors.accentStrong,
                      border: Border.all(
                        color: ui.colors.background,
                        width: ui.sizes.borderWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
