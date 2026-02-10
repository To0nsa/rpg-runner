import 'package:flutter/material.dart';

import 'control_button_visuals.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.affordable = true,
    this.cooldownTicksLeft = 0,
    this.cooldownTicksTotal = 0,
    this.size = 72,
    this.backgroundColor = const Color(0x33000000),
    this.foregroundColor = Colors.white,
    this.labelFontSize = 12,
    this.labelGap = 2,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool affordable;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    final visual = ControlButtonVisualState.resolve(
      affordable: affordable,
      cooldownTicksLeft: cooldownTicksLeft,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );

    return ControlButtonShell(
      size: size,
      cooldownTicksLeft: cooldownTicksLeft,
      cooldownTicksTotal: cooldownTicksTotal,
      child: Material(
        color: visual.backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: visual.interactable ? (_) => onPressed() : null,
          onTap: null,
          child: ControlButtonContent(
            label: label,
            icon: icon,
            foregroundColor: visual.foregroundColor,
            labelFontSize: labelFontSize,
            labelGap: labelGap,
          ),
        ),
      ),
    );
  }
}
