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
    this.isValueEnabled,
    this.size = AppSegmentedControlSize.md,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget Function(BuildContext context, T value) labelBuilder;
  final bool enabled;

  /// Disables individual options without changing the whole control's state.
  /// The parent must keep [selected] valid when an option becomes unavailable.
  final bool Function(T value)? isValueEnabled;
  final AppSegmentedControlSize size;

  @override
  Widget build(BuildContext context) {
    assert(values.isNotEmpty, 'Provide at least one segment value.');

    final ui = context.ui;
    final theme = context.segmentedControls;
    final spec = theme.resolveSpec(ui: ui, size: size);

    // Keep app-bar selectors content-sized, while allowing labels to wrap when
    // the parent has less width. Both sizes retain full, non-overlapping targets.
    return IntrinsicWidth(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(spec.radius),
          border: Border.all(color: theme.border, width: spec.borderWidth),
        ),
        child: Padding(
          padding: EdgeInsets.all(spec.inset + spec.borderWidth),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: spec.spacing,
              children: [
                for (final value in values)
                  Expanded(
                    child: _buildSegment(context, value, ui, theme, spec),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    T value,
    UiTokens ui,
    UiSegmentedControlTheme theme,
    UiSegmentedControlSpec spec,
  ) {
    final isSelected = value == selected;
    final valueEnabled = enabled && (isValueEnabled?.call(value) ?? true);
    Color disabledColor(Color color) => valueEnabled
        ? color
        : color.withValues(alpha: color.a * theme.disabledAlpha);
    final label = labelBuilder(context, value);

    return MergeSemantics(
      key: ValueKey(value),
      child: Semantics(
        selected: isSelected,
        inMutuallyExclusiveGroup: true,
        child: TextButton(
          // A selected choice remains enabled for focus and accessibility, but
          // activating it does not repeat a settings write or clear selection.
          onPressed: valueEnabled
              ? () {
                  if (!isSelected && (isValueEnabled?.call(value) ?? true)) {
                    onChanged(value);
                  }
                }
              : null,
          style: ButtonStyle(
            alignment: Alignment.center,
            backgroundColor: WidgetStatePropertyAll(
              isSelected
                  ? disabledColor(theme.selectedBackground)
                  : Colors.transparent,
            ),
            foregroundColor: WidgetStatePropertyAll(
              disabledColor(
                isSelected ? theme.selectedForeground : theme.foreground,
              ),
            ),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed) ||
                  states.contains(WidgetState.focused)) {
                return theme.selectedForeground.withValues(
                  alpha: theme.pressedOverlayAlpha,
                );
              }
              if (states.contains(WidgetState.hovered)) {
                return theme.selectedForeground.withValues(
                  alpha: theme.hoverOverlayAlpha,
                );
              }
              return Colors.transparent;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              final color = states.contains(WidgetState.focused)
                  ? ui.colors.outlineStrong
                  : isSelected
                  ? disabledColor(theme.selectedBorder)
                  : Colors.transparent;
              return BorderSide(color: color, width: spec.borderWidth);
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(spec.segmentRadius),
              ),
            ),
            textStyle: WidgetStatePropertyAll(
              ui.text.label.merge(spec.textStyle),
            ),
            padding: WidgetStatePropertyAll(spec.padding),
            minimumSize: WidgetStatePropertyAll(
              Size(ui.sizes.tapTarget, spec.height),
            ),
            visualDensity: VisualDensity.standard,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
          ),
          child: DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            child: spec.showSelectedIcon
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: spec.spacing,
                    children: [
                      Visibility(
                        visible: isSelected,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Icon(Icons.check, size: ui.sizes.iconSize.sm),
                      ),
                      Flexible(child: label),
                    ],
                  )
                : label,
          ),
        ),
      ),
    );
  }
}
