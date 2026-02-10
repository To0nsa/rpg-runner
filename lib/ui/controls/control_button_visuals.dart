import 'package:flutter/material.dart';

import 'cooldown_ring.dart';

/// Resolved visual state for a control button.
///
/// Buttons are interactable only when affordable and not on cooldown.
@immutable
class ControlButtonVisualState {
  const ControlButtonVisualState._({
    required this.interactable,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory ControlButtonVisualState.resolve({
    required bool affordable,
    required int cooldownTicksLeft,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return ControlButtonVisualState._(
      interactable: affordable && cooldownTicksLeft <= 0,
      backgroundColor: affordable
          ? backgroundColor
          : _disabledBackground(backgroundColor),
      foregroundColor: affordable
          ? foregroundColor
          : _disabledForeground(foregroundColor),
    );
  }

  final bool interactable;
  final Color backgroundColor;
  final Color foregroundColor;
}

/// Shared circular shell used by action controls.
///
/// This keeps cooldown ring rendering consistent for tap and directional
/// controls.
class ControlButtonShell extends StatelessWidget {
  const ControlButtonShell({
    super.key,
    required this.size,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.child,
  });

  final double size;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
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
}

/// Shared icon + label content for circular control buttons.
class ControlButtonContent extends StatelessWidget {
  const ControlButtonContent({
    super.key,
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.labelFontSize,
    required this.labelGap,
  });

  final String label;
  final IconData icon;
  final Color foregroundColor;
  final double labelFontSize;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor),
          SizedBox(height: labelGap),
          Text(
            label,
            style: TextStyle(fontSize: labelFontSize, color: foregroundColor),
          ),
        ],
      ),
    );
  }
}

Color _disabledForeground(Color color) => color.withValues(alpha: 0.35);

Color _disabledBackground(Color color) =>
    color.withValues(alpha: color.a * 0.6);
