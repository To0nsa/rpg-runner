import 'package:flutter/material.dart';

import 'tool_ui_tokens.dart';

/// Keeps a preview above a tabbed workspace, with room for controls on short
/// windows and at larger text scales. Callers own tab state and content scroll.
class ToolPreviewWorkspace extends StatelessWidget {
  const ToolPreviewWorkspace({
    super.key,
    required this.header,
    required this.preview,
    required this.tabs,
    required this.content,
    required this.scrollKey,
  });

  final Widget header, preview, tabs, content;
  final PageStorageKey<String> scrollKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minimumHeight = 680 * MediaQuery.textScalerOf(context).scale(1);
      return SingleChildScrollView(
        key: scrollKey,
        child: SizedBox(
          height: constraints.maxHeight < minimumHeight
              ? minimumHeight
              : constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: ToolUiTokens.controlGap),
              Flexible(flex: 4, child: preview),
              const SizedBox(height: ToolUiTokens.controlGap),
              tabs,
              const SizedBox(height: ToolUiTokens.controlGap),
              Expanded(flex: 5, child: content),
            ],
          ),
        ),
      );
    },
  );
}
