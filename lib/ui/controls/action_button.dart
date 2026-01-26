import 'package:flutter/material.dart';

import 'cooldown_ring.dart';

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.onPressedDown,
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
  final VoidCallback? onPressedDown;
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
    final interactable = affordable && cooldownTicksLeft <= 0;
    final effectiveForeground = affordable
        ? foregroundColor
        : _disabledForeground(foregroundColor);
    final effectiveBackground = affordable
        ? backgroundColor
        : _disabledBackground(backgroundColor);

    final useTapDown = onPressedDown != null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: effectiveBackground,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: interactable && !useTapDown ? onPressed : null,
              onTapDown: interactable && useTapDown
                  ? (_) => onPressedDown?.call()
                  : null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: effectiveForeground),
                  SizedBox(height: labelGap),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      color: effectiveForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IgnorePointer(
            child: CooldownRing(
              cooldownTicksLeft: cooldownTicksLeft,
              cooldownTicksTotal: cooldownTicksTotal,
            ),
          ),
        ],
      ),
    );
  }

  Color _disabledForeground(Color color) => color.withValues(alpha: 0.35);

  Color _disabledBackground(Color color) =>
      color.withValues(alpha: color.a * 0.6);
}
