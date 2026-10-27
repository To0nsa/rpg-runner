import 'package:flutter/material.dart';

import 'app_icon_button.dart';
import 'attention_marker.dart';

/// Shared icon-only menu geometry; sections may expose their selected state.
class MenuIconColumn extends StatelessWidget {
  const MenuIconColumn({super.key, required this.actions});
  final List<MenuIconAction> actions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      for (final action in actions)
        Semantics(
          selected: action.selected,
          child: AttentionMarker(
            visible: action.needsAttention,
            semanticLabel: action.attentionLabel,
            child: AppIconButton(
            icon: action.icon,
            tooltip: action.tooltip,
            onPressed: action.onPressed,
            ),
          ),
        ),
    ],
  );
}

class MenuIconAction {
  const MenuIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected,
    this.needsAttention = false,
    this.attentionLabel = 'New activity',
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool? selected;
  final bool needsAttention;
  final String attentionLabel;
}
