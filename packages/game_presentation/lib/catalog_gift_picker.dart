import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';

import 'catalog_gift.dart';
import 'catalog_item.dart';
import 'game_localization.dart';

/// Shared catalogue selection for Admin gifts and authored chapter rewards.
/// Callers own the permitted catalogue, draft and eventual ownership operation.
class CatalogGiftPicker extends StatefulWidget {
  const CatalogGiftPicker({
    super.key,
    required this.catalog,
    required this.characters,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });
  final List<GameCatalogItem> catalog;
  final List<String> characters;
  final List<CatalogGift> selected;
  final ValueChanged<CatalogGift> onToggle;
  final bool enabled;
  @override
  State<CatalogGiftPicker> createState() => _CatalogGiftPickerState();
}

class _CatalogGiftPickerState extends State<CatalogGiftPicker> {
  final _search = TextEditingController();
  String _category = 'All', _character = '';
  @override
  void initState() {
    super.initState();
    _character = widget.characters.firstOrNull ?? '';
    _search.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void didUpdateWidget(CatalogGiftPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.characters.contains(_character)) {
      _character = widget.characters.firstOrNull ?? '';
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = widget.catalog
        .where(
          (item) =>
              item.supportsCharacter(_character) &&
              (_category == 'All' ||
                  (_category == 'Items'
                      ? item.kind == 'gear'
                      : item.kind != 'gear')) &&
              '${item.displayName(context.gameL10n)} ${item.itemId} ${item.slot}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return ToolVisualCatalogLayout(
      searchController: _search,
      searchKey: const Key('catalog-search'),
      searchLabel: 'Search items and skills',
      searchHint: 'Name or ID',
      clearSearchKey: const Key('clear-search'),
      clearSearchTooltip: 'Clear search',
      countKey: const Key('catalog-count'),
      countLabel:
          '${items.length} available · ${widget.selected.length}/8 selected',
      gridKey: const Key('gift-catalog'),
      emptyKey: const Key('empty-catalog'),
      emptyMessage: 'No matching gifts.',
      gridHeight: 390,
      itemCount: items.length,
      onSearchSubmitted: () {},
      filters: [
        for (final name in ['All', 'Items', 'Skills'])
          ChoiceChip(
            label: Text(name),
            selected: _category == name,
            onSelected: (_) => setState(() => _category = name),
          ),
        if (widget.characters.isNotEmpty)
          DropdownButton<String>(
            value: _character,
            underline: const SizedBox.shrink(),
            items: [
              for (final character in widget.characters)
                DropdownMenuItem(
                  value: character,
                  child: Text('Skills for $character'),
                ),
            ],
            onChanged: widget.enabled
                ? (value) => setState(() => _character = value!)
                : null,
          ),
      ],
      itemBuilder: (context, index) {
        final item = items[index];
        final gift = CatalogGift(
          item: item,
          characterId: item.kind == 'gear' ? null : _character,
        );
        return ToolVisualCatalogCard(
          key: ValueKey(gift.key),
          semanticsLabel: 'Gift ${gift.label(context.gameL10n)}',
          tooltipMessage:
              '${item.displayName(context.gameL10n)}\n${item.itemId} · ${item.slot}',
          selected: widget.selected.any((value) => value.key == gift.key),
          enabled:
              widget.enabled &&
              (widget.selected.length < 8 ||
                  widget.selected.any((value) => value.key == gift.key)),
          preview: Center(child: item.icon(size: 48)),
          title: item.displayName(context.gameL10n),
          subtitle: item.kind == 'gear'
              ? 'Account · ${item.slot}'
              : '$_character · ${item.slot}',
          onTap: () => widget.onToggle(gift),
        );
      },
    );
  }
}
