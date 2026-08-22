import 'package:flutter/material.dart';

import 'editor_ui_tokens.dart';

/// Shared search, filters, count, and grid shell for visual authoring catalogs.
///
/// Callers retain domain filtering and selection state. This widget standardizes
/// only presentation and keyboard submission; it owns no source or identity.
class EditorVisualCatalogLayout extends StatelessWidget {
  const EditorVisualCatalogLayout({
    super.key,
    required this.searchController,
    required this.searchKey,
    required this.searchLabel,
    required this.searchHint,
    required this.clearSearchKey,
    required this.clearSearchTooltip,
    required this.filters,
    required this.countKey,
    required this.countLabel,
    required this.gridKey,
    required this.emptyKey,
    required this.emptyMessage,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSearchSubmitted,
    this.enabled = true,
    this.autofocusSearch = false,
    this.gridHeight = 272,
  });

  final TextEditingController searchController;
  final Key searchKey;
  final String searchLabel;
  final String searchHint;
  final Key clearSearchKey;
  final String clearSearchTooltip;
  final List<Widget> filters;
  final Key countKey;
  final String countLabel;
  final Key gridKey;
  final Key emptyKey;
  final String emptyMessage;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback onSearchSubmitted;
  final bool enabled;
  final bool autofocusSearch;
  final double gridHeight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        key: searchKey,
        controller: searchController,
        autofocus: autofocusSearch,
        enabled: enabled,
        textInputAction: TextInputAction.search,
        onSubmitted: enabled ? (_) => onSearchSubmitted() : null,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: searchLabel,
          hintText: searchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  key: clearSearchKey,
                  tooltip: clearSearchTooltip,
                  onPressed: enabled ? searchController.clear : null,
                  icon: const Icon(Icons.clear),
                ),
        ),
      ),
      const SizedBox(height: EditorUiTokens.controlGap),
      Wrap(
        spacing: EditorUiTokens.controlGap,
        runSpacing: EditorUiTokens.controlGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: filters,
      ),
      const SizedBox(height: EditorUiTokens.controlGap),
      Text(
        countLabel,
        key: countKey,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: EditorUiTokens.controlGap),
      SizedBox(
        height: gridHeight,
        child: itemCount == 0
            ? Center(
                key: emptyKey,
                child: Text(emptyMessage, textAlign: TextAlign.center),
              )
            : GridView.builder(
                key: gridKey,
                primary: false,
                itemCount: itemCount,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisExtent: 174,
                  crossAxisSpacing: EditorUiTokens.controlGap,
                  mainAxisSpacing: EditorUiTokens.controlGap,
                ),
                itemBuilder: itemBuilder,
              ),
      ),
    ],
  );
}

/// Shared selectable card chrome for visual authoring catalogs.
///
/// The supplied preview and labels remain domain-owned. Selection changes are
/// delegated to the caller and have no persistence side effects here.
class EditorVisualCatalogCard extends StatelessWidget {
  const EditorVisualCatalogCard({
    super.key,
    required this.semanticsLabel,
    required this.tooltipMessage,
    required this.selected,
    required this.enabled,
    required this.preview,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String semanticsLabel;
  final String tooltipMessage;
  final bool selected;
  final bool enabled;
  final Widget preview;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltipMessage,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(EditorUiTokens.controlGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: preview),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
