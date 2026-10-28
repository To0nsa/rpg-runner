import 'package:flutter/material.dart';

import 'package:tool_ui/tool_ui.dart';

/// Shared choice-chip group used for compact prefab-editor selectors.
class PrefabEditorChoiceChipGroup<T> extends StatelessWidget {
  const PrefabEditorChoiceChipGroup({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
    this.chipKeyBuilder,
  });

  final List<T> items;
  final T? selectedValue;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelected;
  final Key Function(T item)? chipKeyBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ToolUiTokens.controlGap,
      runSpacing: ToolUiTokens.controlGap,
      children: [
        for (final item in items)
          ChoiceChip(
            key: chipKeyBuilder?.call(item),
            label: Text(labelBuilder(item)),
            selected: selectedValue == item,
            onSelected: (selected) {
              if (!selected) {
                return;
              }
              onSelected(item);
            },
          ),
      ],
    );
  }
}
