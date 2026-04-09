import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared compact summary block used at the top of prefab-editor side panels.
class PrefabEditorPanelSummary extends StatelessWidget {
  const PrefabEditorPanelSummary({
    super.key,
    this.primaryText,
    this.secondaryText,
    this.noticeText,
  });

  final String? primaryText;
  final String? secondaryText;
  final String? noticeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primaryText != null) Text(primaryText!),
        if (primaryText != null && secondaryText != null)
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
        if (secondaryText != null)
          Text(secondaryText!, style: theme.textTheme.titleSmall),
        if (noticeText != null) ...[
          const SizedBox(height: 4),
          Text(noticeText!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
