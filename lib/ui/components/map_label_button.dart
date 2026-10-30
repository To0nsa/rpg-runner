import 'package:flutter/material.dart';

import '../theme/ui_tokens.dart';
import '../theme/ui_world_palette.dart';

/// Text and icon treatment shared by clickable labels on the two maps.
class MapLabelButton extends StatelessWidget {
  const MapLabelButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticsLabel,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: UiWorldPalette.mist200,
        minimumSize: Size(ui.sizes.tapTarget, ui.sizes.tapTarget),
        padding: EdgeInsets.symmetric(horizontal: ui.space.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, shadows: mapLabelShadows),
          SizedBox(width: ui.space.xxs),
          Flexible(
            child: Text(
              label,
              style: ui.text.headline.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: UiWorldPalette.mist200,
                shadows: mapLabelShadows,
              ),
            ),
          ),
        ],
      ),
    );
    if (semanticsLabel case final label?) {
      return Semantics(
        label: label,
        button: true,
        onTap: onPressed,
        child: ExcludeSemantics(child: button),
      );
    }
    return button;
  }
}

const mapLabelShadows = [
  Shadow(color: UiWorldPalette.ink900, blurRadius: 3),
  Shadow(color: UiWorldPalette.ink900, blurRadius: 2, offset: Offset(0, 1)),
];
