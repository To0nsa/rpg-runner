import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared title + metadata stack used by prefab-editor list rows.
class PrefabEditorRowMetadata extends StatelessWidget {
  const PrefabEditorRowMetadata({
    super.key,
    required this.title,
    required this.metadataLines,
    required this.isSelected,
  });

  final String title;
  final List<String> metadataLines;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final lines = metadataLines
        .where((line) => line.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        for (var i = 0; i < lines.length; i += 1) ...[
          SizedBox(
            height: i == 0
                ? PrefabEditorUiTokens.rowTitleGap
                : PrefabEditorUiTokens.rowMetadataGap,
          ),
          Text(lines[i]),
        ],
      ],
    );
  }
}
