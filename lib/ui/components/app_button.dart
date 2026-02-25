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

  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setFocused(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
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
    required Color foreground,
    required UiButtonTheme buttons,
    required bool enabled,
  }) {
    if (!enabled) {
      return base.withValues(alpha: buttons.disabledBackgroundAlpha);
    }

    var color = base;
    if (_pressed) {
      color = _blendOver(
        base: color,
        overlay: UiBrandPalette.black,
        alpha: buttons.pressedOverlayAlpha + 0.08,
      );
    } else {
      if (_hovered) {
        color = _blendOver(
          base: color,
          overlay: foreground,
          alpha: buttons.hoverOverlayAlpha + 0.04,
        );
      }
      if (_focused) {
        color = _blendOver(base: color, overlay: foreground, alpha: 0.08);
      }
    }
    return color;
  }

  Color _resolveBorderColor({
    required Color base,
    required Color foreground,
    required UiButtonTheme buttons,
    required bool enabled,
  }) {
    if (!enabled) {
      return base.withValues(alpha: buttons.disabledBorderAlpha);
    }
    if (_pressed) {
      return _blendOver(base: base, overlay: UiBrandPalette.black, alpha: 0.1);
    }
    if (_hovered || _focused) {
      return _blendOver(base: base, overlay: foreground, alpha: 0.12);
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final buttons = context.buttons;

    final spec = buttons.resolveSpec(
      ui: ui,
      variant: widget.variant,
      size: widget.size,
    );
    final enabled = widget.onPressed != null;
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
      foreground: spec.foreground,
      buttons: buttons,
      enabled: enabled,
    );
    final outerBottom = _resolveSurfaceColor(
      base: spec.surfaceBottom,
      foreground: spec.foreground,
      buttons: buttons,
      enabled: enabled,
    );
    final innerTop = _resolveSurfaceColor(
      base: spec.insetTop,
      foreground: spec.foreground,
      buttons: buttons,
      enabled: enabled,
    );
    final innerBottom = _resolveSurfaceColor(
      base: spec.insetBottom,
      foreground: spec.foreground,
      buttons: buttons,
      enabled: enabled,
    );
    final outerBorder = _resolveBorderColor(
      base: spec.border,
      foreground: spec.foreground,
      buttons: buttons,
      enabled: enabled,
    );
    final innerBorder = _resolveBorderColor(
      base: spec.insetBorder,
      foreground: spec.foreground,
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
    final pressedOffset = enabled && _pressed ? 1.5 : 0.0;
    final glowStrength = !enabled
        ? 0.0
        : _focused
        ? 0.45
        : _hovered
        ? 0.25
        : 0.0;
    final shadowColor = enabled
        ? spec.shadow
        : spec.shadow.withValues(alpha: buttons.disabledBackgroundAlpha);
    final glowColor = spec.glow.withValues(alpha: spec.glow.a * glowStrength);

    return SizedBox(
      width: spec.width,
      height: spec.height,
      child: AnimatedContainer(
        duration: _stateAnimationDuration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, pressedOffset, 0),
        decoration: BoxDecoration(
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
              offset: Offset(0, _pressed ? 2 : 5),
            ),
            if (glowStrength > 0)
              BoxShadow(
                color: glowColor,
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 0),
              ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(bevelInset),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: Material(
              type: MaterialType.transparency,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [innerTop, innerBottom],
                  ),
                  border: Border.all(color: innerBorder),
                ),
                child: InkWell(
                  onTap: widget.onPressed,
                  onHover: enabled ? _setHovered : null,
                  onFocusChange: enabled ? _setFocused : null,
                  onHighlightChanged: enabled ? _setPressed : null,
                  customBorder: RoundedRectangleBorder(
                    borderRadius: contentRadius,
                  ),
                  splashColor: textColor.withValues(
                    alpha: buttons.pressedOverlayAlpha + 0.06,
                  ),
                  hoverColor: textColor.withValues(
                    alpha: buttons.hoverOverlayAlpha,
                  ),
                  highlightColor: textColor.withValues(
                    alpha: buttons.pressedOverlayAlpha,
                  ),
                  child: Padding(
                    padding: spec.padding,
                    child: SizedBox.expand(
                      child: Align(
                        alignment: Alignment.center,
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
