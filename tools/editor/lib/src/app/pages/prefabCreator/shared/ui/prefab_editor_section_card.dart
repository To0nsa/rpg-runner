import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared bordered sub-section used inside prefab-editor inspectors.
class PrefabEditorSectionCard extends StatelessWidget {
  const PrefabEditorSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.sectionKey,
  });

  final String title;
  final String? description;
  final Widget child;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(PrefabEditorUiTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!),
          ],
          const SizedBox(height: PrefabEditorUiTokens.sectionGap),
          child,
        ],
      ),
    );
  }
}
