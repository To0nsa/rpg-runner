import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Canonical bordered subsection for grouping related inspector controls.
///
/// Optional expansion remains presentation-only. A containing panel or sidebar
/// owns scrolling, so section bodies always keep their natural height.
class EditorSectionCard extends StatefulWidget {
  const EditorSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.trailing,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.expanded,
    this.expansionKey,
    this.onExpansionChanged,
  }) : assert(
         collapsible || expanded == true || initiallyExpanded,
         'Non-collapsible sections must start expanded.',
       );

  final String title;
  final String? description;
  final Widget child;
  final Widget? trailing;
  final bool collapsible;
  final bool initiallyExpanded;
  final bool? expanded;
  final Key? expansionKey;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<EditorSectionCard> createState() => _EditorSectionCardState();
}

class _EditorSectionCardState extends State<EditorSectionCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded ?? widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant EditorSectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded case final expanded?) {
      _expanded = expanded;
    } else if (!widget.collapsible) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(EditorUiTokens.panelRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildHeader(context),
        if (_expanded)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: EditorUiTokens.panelPadding,
              end: EditorUiTokens.panelPadding,
              bottom: EditorUiTokens.panelPadding,
            ),
            child: widget.child,
          ),
      ],
    ),
  );

  Widget _buildHeader(BuildContext context) {
    final header = Padding(
      padding: EditorUiTokens.panelInsets,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (widget.description case final description?) ...<Widget>[
                  const SizedBox(height: EditorUiTokens.rowTitleGap),
                  Text(description),
                ],
              ],
            ),
          ),
          if (widget.trailing case final trailing?) ...<Widget>[
            const SizedBox(width: EditorUiTokens.controlGap),
            trailing,
          ],
          if (widget.collapsible) ...<Widget>[
            const SizedBox(width: EditorUiTokens.controlGap),
            Tooltip(
              message: '${_expanded ? 'Collapse' : 'Expand'} ${widget.title}',
              child: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            ),
          ],
        ],
      ),
    );
    if (!widget.collapsible) return header;
    return Semantics(
      button: true,
      expanded: _expanded,
      child: InkWell(
        key: widget.expansionKey,
        onTap: _toggleExpanded,
        child: header,
      ),
    );
  }

  void _toggleExpanded() {
    final next = !_expanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpansionChanged?.call(next);
  }
}
