import 'package:flutter/material.dart';

import 'cooldown_ring.dart';
import 'controls_tuning.dart';
import 'control_resource_usage.dart';
import '../theme/ui_action_button_theme.dart';
import '../components/hud_frame.dart';

/// Resolved visual state for a control button.
///
/// Buttons are interactable only when affordable and not on cooldown.
@immutable
class ControlButtonVisualState {
  const ControlButtonVisualState._({
    required this.interactable,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.backgroundGradient,
  });

  factory ControlButtonVisualState.resolve({
    required bool affordable,
    required int cooldownTicksLeft,
    required Color backgroundColor,
    required Color foregroundColor,
    required ControlResourceUsage resources,
    required UiActionButtonTheme theme,
  }) {
    final resourceColors = theme.resourceBackgrounds(resources);
    final colors = resourceColors.isEmpty
        ? [backgroundColor]
        : [
            for (final color in resourceColors)
              color.withValues(alpha: backgroundColor.a),
          ];
    final resolvedColors = [
      for (final color in colors)
        affordable ? color : _disabledBackground(color),
    ];
    return ControlButtonVisualState._(
      interactable: affordable && cooldownTicksLeft <= 0,
      backgroundColor: resolvedColors.first,
      backgroundGradient: resolvedColors.length > 1
          ? LinearGradient(colors: resolvedColors)
          : null,
      foregroundColor: affordable
          ? (cooldownTicksLeft > 0
                ? foregroundColor.withValues(alpha: 0.55)
                : foregroundColor)
          : _disabledForeground(foregroundColor),
    );
  }

  final bool interactable;
  final Color backgroundColor;
  final Color foregroundColor;
  final Gradient? backgroundGradient;
}

/// Shared paint surface so tap, hold, and aim controls show identical resources.
class ControlButtonSurface extends StatelessWidget {
  const ControlButtonSurface({
    super.key,
    required this.visual,
    required this.child,
  });

  final ControlButtonVisualState visual;
  final Widget child;

  @override
  Widget build(BuildContext context) => HudMedallion(
    child: Material(
      // A mixed-resource gradient must be the only fill or its alpha compounds.
      color: visual.backgroundGradient == null
          ? visual.backgroundColor
          : Colors.transparent,
      shape: const CircleBorder(),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: visual.backgroundGradient,
        ),
        child: child,
      ),
    ),
  );
}

/// Shared circular shell used by action controls.
///
/// This keeps cooldown ring rendering consistent for tap and directional
/// controls.
/// `cooldownTicksLeft`/`cooldownTicksTotal` are simulation ticks.
class ControlButtonShell extends StatelessWidget {
  const ControlButtonShell({
    super.key,
    required this.size,
    required this.cooldownTicksLeft,
    required this.cooldownTicksTotal,
    required this.cooldownRing,
    required this.child,
    required this.label,
    required this.interactable,
    this.onSemanticTap,
  });

  final double size;
  final int cooldownTicksLeft;
  final int cooldownTicksTotal;
  final CooldownRingTuning cooldownRing;
  final Widget child;
  final String label;
  final bool interactable;
  final VoidCallback? onSemanticTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: interactable,
      onTap: interactable ? onSemanticTap : null,
      child: ExcludeSemantics(
        child: SizedBox(
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
                  tuning: cooldownRing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centered slot symbol, sized relative to the circular touch target.
class ControlButtonContent extends StatelessWidget {
  const ControlButtonContent({
    super.key,
    required this.icon,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: Icon(
              icon,
              color: foregroundColor,
              size: (constraints.biggest.shortestSide * 0.52).clamp(24.0, 44.0),
            ),
          );
        },
      ),
    );
  }
}

Color _disabledForeground(Color color) => color.withValues(alpha: 0.35);

Color _disabledBackground(Color color) =>
    color.withValues(alpha: color.a * 0.6);
