import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Canonical selectable row card for editor owner and catalog lists.
///
/// Selection is visual only; callers retain navigation and mutation authority
/// through [onTap]. Optional preview, trailing, and detail slots keep list rows
/// structurally consistent without route-specific card shells.
class EditorSelectableCard extends StatelessWidget {
  const EditorSelectableCard({
    super.key,
    required this.child,
    required this.isSelected,
    this.onTap,
    this.preview,
    this.details,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: EditorUiTokens.controlGap),
  });

  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? preview;
  final Widget? details;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: margin,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Ink(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.09)
            : null,
        child: Padding(
          padding: EditorUiTokens.panelInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: child),
                  if (preview case final preview?) ...<Widget>[
                    const SizedBox(width: EditorUiTokens.rowPreviewGap),
                    preview,
                  ],
                  if (trailing case final trailing?) ...<Widget>[
                    const SizedBox(width: EditorUiTokens.rowTrailingGap),
                    trailing,
                  ],
                ],
              ),
              if (details case final details?) ...<Widget>[
                const SizedBox(height: EditorUiTokens.controlGap),
                details,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
