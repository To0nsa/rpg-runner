import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Canonical row card for editor owner, catalog, and composition lists.
///
/// Selection is visual only; callers retain navigation and mutation authority
/// through [onTap]. Optional leading, preview, trailing, and detail slots keep
/// list rows structurally consistent without route-specific card shells.
class EditorListCard extends StatelessWidget {
  const EditorListCard({
    super.key,
    required this.child,
    this.isSelected = false,
    this.onTap,
    this.leading,
    this.preview,
    this.details,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: EditorUiTokens.controlGap),
  });

  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? leading;
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
                  if (leading case final leading?) ...<Widget>[
                    leading,
                    const SizedBox(width: EditorUiTokens.rowPreviewGap),
                  ],
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
