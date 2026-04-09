import 'package:flutter/material.dart';

import 'prefab_editor_ui_tokens.dart';

/// Shared panel shell for inspector, scene, and display cards.
class PrefabEditorPanelCard extends StatelessWidget {
  const PrefabEditorPanelCard({
    super.key,
    required this.title,
    required this.child,
    this.cardKey,
    this.scrollable = false,
    this.expandBody = false,
  });

  final String title;
  final Widget child;
  final Key? cardKey;
  final bool scrollable;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    Widget body = child;
    if (expandBody) {
      body = Expanded(child: child);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        body,
      ],
    );

    return Card(
      key: cardKey,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: PrefabEditorUiTokens.panelInsets,
        child: scrollable ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}
