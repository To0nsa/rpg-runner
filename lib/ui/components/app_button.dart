import 'dart:math' as math;

import 'package:flutter/material.dart';

export '../theme/ui_button_theme.dart' show AppButtonSize, AppButtonVariant;

import '../theme/ui_button_theme.dart';
import '../theme/ui_tokens.dart';

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  static const Duration _stateAnimationDuration = Duration(milliseconds: 120);

  // Tracks pointer-down highlight state to render pressed visuals.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Color _blendOver({
    required Color base,
    required Color overlay,
    required double alpha,
  }) {
    if (alpha <= 0) return base;
    return Color.alphaBlend(overlay.withValues(alpha: alpha), base);
  }

  Color _resolveSurfaceColor({
    required Color base,
    required UiButtonTheme buttons,
    required bool enabled,
  }) {
    if (!enabled) {
      return base.withValues(alpha: buttons.disabledBackgroundAlpha);
    }

    if (_pressed) {
      base = _blendOver(
        base: base,
        overlay: UiBrandPalette.black,
        alpha: buttons.pressedOverlayAlpha,
      );
    }
    return base;
  }

  Color _resolveBorderColor({
    required Color base,
    required UiButtonTheme buttons,
    required bool enabled,
  }) {
    if (!enabled) {
      return base.withValues(alpha: buttons.disabledBorderAlpha);
    }

    if (_pressed) {
      return _blendOver(
        base: base,
        overlay: UiBrandPalette.black,
        alpha: buttons.pressedOverlayAlpha);
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final buttons = context.buttons;

    // 1) Resolve all theme-driven visual tokens for this button.
    final spec = buttons.resolveSpec(
      ui: ui,
      variant: widget.variant,
      size: widget.size,
    );
    final enabled = widget.onPressed != null;

    // 2) Build geometry for the beveled frame and inset panel.
    final outerRadius = BorderRadius.circular(ui.radii.sm);
    final bevelInset = math.max(1.0, ui.sizes.borderWidth);
    final innerRadius = BorderRadius.circular(
      math.max(0.0, ui.radii.sm - bevelInset),
    );
    final contentRadius = BorderRadius.circular(
      math.max(0.0, ui.radii.sm - bevelInset - 1),
    );

    final outerTop = _resolveSurfaceColor(
      base: spec.surfaceTop,
      buttons: buttons,
      enabled: enabled,
    );
    final outerBottom = _resolveSurfaceColor(
      base: spec.surfaceBottom,
      buttons: buttons,
      enabled: enabled,
    );
    final innerTop = _resolveSurfaceColor(
      base: spec.insetTop,
      buttons: buttons,
      enabled: enabled,
    );
    final innerBottom = _resolveSurfaceColor(
      base: spec.insetBottom,
      buttons: buttons,
      enabled: enabled,
    );
    final outerBorder = _resolveBorderColor(
      base: spec.border,
      buttons: buttons,
      enabled: enabled,
    );
    final innerBorder = _resolveBorderColor(
      base: spec.insetBorder,
      buttons: buttons,
      enabled: enabled,
    );
    final textColor = enabled
        ? spec.foreground
        : spec.foreground.withValues(alpha: buttons.disabledForegroundAlpha);
    final textStyle = spec.textStyle.copyWith(
      color: textColor,
      height: 1,
      shadows: [
        Shadow(
          color: UiBrandPalette.black.withValues(alpha: enabled ? 0.65 : 0.4),
          blurRadius: _pressed ? 1 : 2.5,
          offset: Offset(0, _pressed ? 0.5 : 1.2),
        ),
      ],
    );
    final textStrutStyle = StrutStyle(
      fontFamily: textStyle.fontFamily,
      fontSize: textStyle.fontSize,
      fontWeight: textStyle.fontWeight,
      height: textStyle.height,
      forceStrutHeight: true,
    );
    // 3) Nudge on press for physical button feedback.
    final pressedOffsetY = enabled && _pressed ? 1.5 : 0.0;
    final pressedOffsetX = enabled && _pressed ? 0.5 : 0.0;
    final shadowColor = enabled
        ? spec.shadow
        : spec.shadow.withValues(alpha: buttons.disabledBackgroundAlpha);

    return SizedBox(
      width: spec.width,
      height: spec.height,
      child: AnimatedContainer(
        duration: _stateAnimationDuration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(pressedOffsetX, pressedOffsetY, 0),
        decoration: BoxDecoration(
          // 4) Outer shell: border + gradient + drop shadow.
          borderRadius: outerRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [outerTop, outerBottom],
          ),
          border: Border.all(color: outerBorder, width: ui.sizes.borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: _pressed ? 4 : 10,
              offset: Offset(_pressed ? 0.5 : 0, _pressed ? 2 : 5),
            ),
          ],
        ),
        child: Padding(
          // 5) Inset gap that creates the bevel effect.
          padding: EdgeInsets.all(bevelInset),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: BoxDecoration(
                  // 6) Inner panel: inset gradient and border.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [innerTop, innerBottom],
                  ),
                  border: Border.all(color: innerBorder),
                ),
                child: InkWell(
                  // 7) Interaction layer and press highlight behavior.
                  onTap: widget.onPressed,
                  onHighlightChanged: enabled ? _setPressed : null,
                  customBorder: RoundedRectangleBorder(
                    borderRadius: contentRadius,
                  ),
                  splashColor: textColor.withValues(
                    alpha: buttons.pressedOverlayAlpha + 0.06,
                  ),
                  highlightColor: textColor.withValues(
                    alpha: buttons.pressedOverlayAlpha,
                  ),
                  child: Padding(
                    padding: spec.padding,
                    child: SizedBox.expand(
                      child: Align(
                        alignment: Alignment.center,
                        // 8) Centered label layer.
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          textWidthBasis: TextWidthBasis.parent,
                          style: textStyle,
                          strutStyle: textStrutStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
