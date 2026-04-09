import 'package:flutter/material.dart';

/// Shared trailing delete affordance for prefab-editor list rows.
class PrefabEditorDeleteButton extends StatelessWidget {
  const PrefabEditorDeleteButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Delete',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.delete_outline),
      onPressed: onPressed,
    );
  }
}
