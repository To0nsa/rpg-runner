import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Determines how an [EditorPanelCard] allocates its body.
enum EditorPanelBodyMode {
  /// The body uses its intrinsic height.
  natural,

  /// The body fills the remaining bounded card height.
  expanded,

  /// The body fills the remaining bounded height and scrolls vertically.
  scrollable,
}

/// Canonical titled card shell for editor panels.
///
/// The card centralizes outline, spacing, header, scrolling, and optional
/// expansion semantics. [EditorPanelBodyMode.expanded] and
/// [EditorPanelBodyMode.scrollable] require a bounded parent height.
/// Collapsible cards intentionally use natural-height bodies so a containing
/// sidebar owns scrolling instead of introducing competing nested scroll views.
class EditorPanelCard extends StatefulWidget {
  const EditorPanelCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.trailing,
    this.bodyMode = EditorPanelBodyMode.natural,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.expansionKey,
    this.onExpansionChanged,
    this.padding = EditorUiTokens.panelInsets,
    this.margin = EdgeInsets.zero,
    this.color,
  }) : assert(
         !collapsible || bodyMode == EditorPanelBodyMode.natural,
         'Collapsible panel bodies must use natural height.',
       );

  final String title;
  final String? description;
  final Widget? trailing;
  final Widget child;
  final EditorPanelBodyMode bodyMode;
  final bool collapsible;
  final bool initiallyExpanded;
  final Key? expansionKey;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  @override
  State<EditorPanelCard> createState() => _EditorPanelCardState();
}

class _EditorPanelCardState extends State<EditorPanelCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: widget.margin,
      color: widget.color,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[_buildHeader(context), if (_expanded) _buildBody()],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: EditorUiTokens.panelPadding,
        top: EditorUiTokens.controlGap,
        end: EditorUiTokens.controlGap,
        bottom: widget.description == null
            ? EditorUiTokens.controlGap
            : EditorUiTokens.rowTitleGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
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
    if (!widget.collapsible) return content;
    return Semantics(
      button: true,
      expanded: _expanded,
      child: InkWell(
        key: widget.expansionKey,
        onTap: _toggleExpanded,
        child: content,
      ),
    );
  }

  Widget _buildBody() {
    final body = Padding(
      padding: widget.padding,
      child: switch (widget.bodyMode) {
        EditorPanelBodyMode.scrollable => SingleChildScrollView(
          child: widget.child,
        ),
        EditorPanelBodyMode.natural ||
        EditorPanelBodyMode.expanded => widget.child,
      },
    );
    return switch (widget.bodyMode) {
      EditorPanelBodyMode.natural => body,
      EditorPanelBodyMode.expanded ||
      EditorPanelBodyMode.scrollable => Expanded(child: body),
    };
  }

  void _toggleExpanded() {
    final next = !_expanded;
    setState(() => _expanded = next);
    widget.onExpansionChanged?.call(next);
  }
}
