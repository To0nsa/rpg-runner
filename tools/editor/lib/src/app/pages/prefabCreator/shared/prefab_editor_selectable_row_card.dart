import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared selected-row shell for prefab-editor right-side lists.
class PrefabEditorSelectableRowCard extends StatelessWidget {
  const PrefabEditorSelectableRowCard({
    super.key,
    required this.child,
    required this.isSelected,
    this.onTap,
    this.preview,
    this.details,
    this.trailing,
    this.margin = const EdgeInsets.only(
      bottom: PrefabEditorUiTokens.controlGap,
    ),
  });

  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? preview;
  final Widget? details;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: margin,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          color: isSelected ? const Color(0x1829C98E) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: child),
                    if (preview != null) ...[
                      const SizedBox(width: PrefabEditorUiTokens.rowPreviewGap),
                      preview!,
                    ],
                    if (trailing != null) ...[
                      const SizedBox(
                        width: PrefabEditorUiTokens.rowTrailingGap,
                      ),
                      trailing!,
                    ],
                  ],
                ),
                if (details != null) ...[
                  const SizedBox(height: PrefabEditorUiTokens.controlGap),
                  details!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
