import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared compact header used at the top of prefab-editor scene panels.
class PrefabEditorSceneHeader extends StatelessWidget {
  const PrefabEditorSceneHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: PrefabEditorUiTokens.rowTitleGap),
                    Text(subtitle!),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: PrefabEditorUiTokens.controlGap),
              Flexible(child: trailing!),
            ],
          ],
        ),
        if (bottom != null) ...[
          const SizedBox(height: PrefabEditorUiTokens.controlGap),
          bottom!,
        ],
      ],
    );
  }
}
