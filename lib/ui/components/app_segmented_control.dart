import 'package:flutter/material.dart';

export '../theme/ui_segmented_control_theme.dart' show AppSegmentedControlSize;

import '../theme/ui_segmented_control_theme.dart';
import '../theme/ui_tokens.dart';

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelBuilder,
    this.enabled = true,
    this.size = AppSegmentedControlSize.md,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget Function(BuildContext context, T value) labelBuilder;
  final bool enabled;
  final AppSegmentedControlSize size;

  @override
  Widget build(BuildContext context) {
    assert(values.isNotEmpty, 'Provide at least one segment value.');

    final ui = context.ui;
    final theme = context.segmentedControls;
    final spec = theme.resolveSpec(ui: ui, size: size);

    final radius = BorderRadius.circular(spec.radius);
    final borderWidth = ui.sizes.borderWidth;
    final borderColor = enabled
        ? theme.border
        : theme.border.withValues(alpha: theme.disabledAlpha);

    final style = ButtonStyle(
      alignment: Alignment.center,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        final isDisabled = states.contains(WidgetState.disabled);
        final isSelected = states.contains(WidgetState.selected);
        final base = isSelected ? theme.selectedBackground : theme.background;
        return isDisabled ? base.withValues(alpha: theme.disabledAlpha) : base;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        final isDisabled = states.contains(WidgetState.disabled);
        final isSelected = states.contains(WidgetState.selected);
        final base = isSelected ? theme.selectedForeground : theme.foreground;
        return isDisabled ? base.withValues(alpha: theme.disabledAlpha) : base;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return theme.foreground.withValues(alpha: theme.pressedOverlayAlpha);
        }
        if (states.contains(WidgetState.hovered)) {
          return theme.foreground.withValues(alpha: theme.hoverOverlayAlpha);
        }
        return null;
      }),
      // We draw the border around the whole control instead of per-segment
      // outlines, which can produce subtle visual artifacts on some devices.
      side: WidgetStateProperty.all(BorderSide.none),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: radius),
      ),
      padding: WidgetStateProperty.all(spec.padding),
      textStyle: WidgetStateProperty.all(spec.textStyle),
      minimumSize: WidgetStateProperty.all(
        Size(ui.sizes.tapTarget, spec.height),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final segments = <ButtonSegment<T>>[
      for (final value in values)
        ButtonSegment<T>(
          value: value,
          label: Center(child: labelBuilder(context, value)),
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SegmentedButton<T>(
          segments: segments,
          selected: {selected},
          showSelectedIcon: spec.showSelectedIcon,
          style: style,
          onSelectionChanged: enabled
              ? (selection) {
                  if (selection.isEmpty) return;
                  onChanged(selection.first);
                }
              : null,
        ),
      ),
    );
  }
}
