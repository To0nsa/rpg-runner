import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

enum PrefabEditorModeTone { create, edit }

/// Shared create/edit mode banner used across prefab-editor inspectors.
class PrefabEditorModeBanner extends StatelessWidget {
  const PrefabEditorModeBanner({
    super.key,
    required this.title,
    required this.details,
    required this.tone,
    this.bannerKey,
  });

  final String title;
  final String details;
  final PrefabEditorModeTone tone;
  final Key? bannerKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      PrefabEditorModeTone.create => const Color(0x143A8DFF),
      PrefabEditorModeTone.edit => const Color(0x1429C98E),
    };

    return Container(
      key: bannerKey,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(PrefabEditorUiTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(details),
        ],
      ),
    );
  }
}
