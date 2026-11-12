import 'package:flutter/material.dart';

/// Consistent placement tools; callers retain their domain's gesture state and
/// resolve pending edits before accepting a tool change.
class EditorPlacementTools<T> extends StatelessWidget {
  const EditorPlacementTools({
    super.key,
    required this.select,
    required this.place,
    required this.move,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.canPlace = true,
  });

  final T select, place, move, selected;
  final ValueChanged<T>? onChanged;
  final String keyPrefix;
  final bool canPlace;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final (value, name, label) in [
        (select, 'select', 'Select'),
        (place, 'place', 'Place'),
        (move, 'move', 'Move'),
      ])
        ChoiceChip(
          key: ValueKey('${keyPrefix}_$name'),
          label: Text(label),
          selected: selected == value,
          onSelected: onChanged == null || (value == place && !canPlace)
              ? null
              : (_) => onChanged!(value),
        ),
    ],
  );
}
