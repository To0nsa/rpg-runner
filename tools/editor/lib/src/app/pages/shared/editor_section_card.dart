import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Canonical bordered subsection for grouping related inspector controls.
class EditorSectionCard extends StatelessWidget {
  const EditorSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EditorUiTokens.panelInsets,
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(EditorUiTokens.panelRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (description case final description?) ...<Widget>[
          const SizedBox(height: EditorUiTokens.rowTitleGap),
          Text(description),
        ],
        const SizedBox(height: EditorUiTokens.sectionGap),
        child,
      ],
    ),
  );
}
