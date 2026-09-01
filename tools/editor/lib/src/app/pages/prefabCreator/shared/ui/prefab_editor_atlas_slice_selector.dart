import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../../atlas/atlas_pixel_rect.dart';
import '../../../../../prefabs/models/models.dart';
import '../../../shared/atlas_region_preview_tile.dart';
import '../../../shared/editor_scene_view_utils.dart';
import '../../../shared/editor_ui_tokens.dart';
import '../../../shared/editor_visual_catalog.dart';

/// Presentation contract for the shared slice selector.
///
/// [autocomplete] keeps dense paint-palette workflows compact, while
/// [visualCatalog] exposes persistent thumbnails and filters for large source
/// catalogs where selection context matters.
enum PrefabEditorAtlasSliceSelectorPresentation { autocomplete, visualCatalog }

/// Shared searchable atlas-slice selector for prefab and module authoring.
///
/// The field filters on slice id, source path, dimensions, and tags. When
/// [defaultScopeTags] are provided, empty queries still show the full slice
/// list, but slices carrying those tags sort ahead of the rest.
class PrefabEditorAtlasSliceSelector extends StatefulWidget {
  const PrefabEditorAtlasSliceSelector({
    super.key,
    required this.slices,
    required this.selectedSliceId,
    required this.onSelectedSliceChanged,
    required this.workspaceRootPath,
    required this.labelText,
    required this.hintText,
    required this.emptyStateMessage,
    this.defaultScopeTags = const <String>[],
    this.fieldKey,
    this.optionKeyPrefix = 'prefab_editor_atlas_slice_option',
    this.optionPreviewKeyPrefix = 'prefab_editor_atlas_slice_option_preview',
    this.selectedPreviewKey,
    this.presentation = PrefabEditorAtlasSliceSelectorPresentation.autocomplete,
    this.prefabOwnerIdsBySliceId = const <String, List<String>>{},
    this.showUsageFilters = false,
    this.gridHeight = 300,
  });

  final List<AtlasSliceDef> slices;
  final String? selectedSliceId;
  final ValueChanged<String?> onSelectedSliceChanged;
  final String workspaceRootPath;
  final String labelText;
  final String hintText;
  final String emptyStateMessage;
  final List<String> defaultScopeTags;
  final Key? fieldKey;
  final String optionKeyPrefix;
  final String optionPreviewKeyPrefix;
  final Key? selectedPreviewKey;

  /// Chooses between a compact autocomplete and a persistent visual catalog.
  final PrefabEditorAtlasSliceSelectorPresentation presentation;

  /// Human owner IDs referencing each slice, used only for search and display.
  ///
  /// The selector never treats usage as exclusivity; callers retain authority
  /// over whether a referenced slice may be selected again.
  final Map<String, List<String>> prefabOwnerIdsBySliceId;

  /// Exposes All, Unused, and Used filters even when every slice is unused.
  final bool showUsageFilters;

  /// Fixed visual-catalog viewport height in logical pixels.
  final double gridHeight;

  @override
  State<PrefabEditorAtlasSliceSelector> createState() =>
      _PrefabEditorAtlasSliceSelectorState();
}

class _PrefabEditorAtlasSliceSelectorState
    extends State<PrefabEditorAtlasSliceSelector> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late EditorUiImageCache _previewImageCache;
  _AtlasSliceUsageFilter _usageFilter = _AtlasSliceUsageFilter.all;
  String? _sourcePathFilter;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _previewImageCache = EditorUiImageCache();
    _controller.addListener(_handleControllerChanged);
    if (_usesAutocomplete) _syncTextFromSelection(force: true);
  }

  @override
  void didUpdateWidget(covariant PrefabEditorAtlasSliceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _previewImageCache.dispose();
      _previewImageCache = EditorUiImageCache();
    }
    if (_sourcePathFilter != null &&
        !widget.slices.any(
          (slice) => slice.sourceImagePath == _sourcePathFilter,
        )) {
      _sourcePathFilter = null;
    }
    if (oldWidget.presentation != widget.presentation) {
      if (_usesAutocomplete) {
        _syncTextFromSelection(force: true);
      } else {
        _controller.clear();
      }
    }
    final selectionChanged =
        oldWidget.selectedSliceId != widget.selectedSliceId;
    final oldHasSelected = _containsSliceId(
      oldWidget.slices,
      widget.selectedSliceId,
    );
    final newHasSelected = _containsSliceId(
      widget.slices,
      widget.selectedSliceId,
    );
    final selectedVisibilityChanged = oldHasSelected != newHasSelected;
    if (_usesAutocomplete && (selectionChanged || selectedVisibilityChanged)) {
      _syncTextFromSelection();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    _previewImageCache.dispose();
    super.dispose();
  }

  AtlasSliceDef? get _selectedSlice {
    final selectedId = widget.selectedSliceId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }
    for (final slice in widget.slices) {
      if (slice.id == selectedId) {
        return slice;
      }
    }
    return null;
  }

  bool get _usesAutocomplete =>
      widget.presentation ==
      PrefabEditorAtlasSliceSelectorPresentation.autocomplete;

  @override
  Widget build(BuildContext context) {
    if (!_usesAutocomplete) return _buildVisualCatalog(context);
    return _buildAutocomplete(context);
  }

  Widget _buildAutocomplete(BuildContext context) {
    final hasSelectableSlices = widget.slices.isNotEmpty;
    final selectedSlice = _selectedSlice;
    final scopedHint = widget.defaultScopeTags.isEmpty
        ? 'Search by slice id or tag.'
        : 'Search by slice id or tag. Preferred tags: '
              '${widget.defaultScopeTags.join(', ')}.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RawAutocomplete<AtlasSliceDef>(
          textEditingController: _controller,
          focusNode: _focusNode,
          displayStringForOption: (slice) => slice.id,
          optionsBuilder: _buildOptions,
          onSelected: _handleOptionSelected,
          fieldViewBuilder:
              (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  key: widget.fieldKey,
                  controller: textEditingController,
                  focusNode: focusNode,
                  enabled: hasSelectableSlices,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.labelText,
                    hintText: widget.hintText,
                    suffixIcon:
                        !hasSelectableSlices ||
                            (textEditingController.text.trim().isEmpty &&
                                widget.selectedSliceId == null)
                        ? null
                        : IconButton(
                            tooltip: 'Clear slice selection',
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSelection,
                          ),
                  ),
                  onSubmitted: (_) {
                    onFieldSubmitted();
                    _handleSubmitted();
                  },
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            final optionList = options.toList(growable: false);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 620,
                    maxHeight: 280,
                  ),
                  child: ListView.builder(
                    key: ValueKey<String>('${widget.optionKeyPrefix}_list'),
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: optionList.length,
                    itemBuilder: (context, index) {
                      final slice = optionList[index];
                      final isSelected = slice.id == widget.selectedSliceId;
                      return ListTile(
                        key: ValueKey<String>(
                          '${widget.optionKeyPrefix}_${slice.id}',
                        ),
                        dense: true,
                        leading: AtlasRegionPreviewTile(
                          key: ValueKey<String>(
                            '${widget.optionPreviewKeyPrefix}_${slice.id}',
                          ),
                          imageCache: _previewImageCache,
                          workspaceRootPath: widget.workspaceRootPath,
                          sourceImagePath: slice.sourceImagePath,
                          region: _regionFor(slice),
                          width: 56,
                          height: 44,
                        ),
                        minLeadingWidth: 56,
                        selected: isSelected,
                        title: Text(slice.id),
                        subtitle: Text(
                          _sliceSubtitle(slice),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, size: 18)
                            : null,
                        onTap: () => onSelected(slice),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        if (!hasSelectableSlices)
          Text(widget.emptyStateMessage)
        else if (selectedSlice == null)
          Text(scopedHint)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AtlasRegionPreviewTile(
                key:
                    widget.selectedPreviewKey ??
                    ValueKey<String>(
                      '${widget.optionKeyPrefix}_selected_preview',
                    ),
                imageCache: _previewImageCache,
                workspaceRootPath: widget.workspaceRootPath,
                sourceImagePath: selectedSlice.sourceImagePath,
                region: _regionFor(selectedSlice),
                width: 72,
                height: 56,
              ),
              const SizedBox(width: EditorUiTokens.rowPreviewGap),
              Expanded(
                child: Text(
                  'Selected: ${selectedSlice.id} · '
                  '${selectedSlice.width}x${selectedSlice.height} px'
                  '${selectedSlice.tags.isEmpty ? '' : ' · tags=${selectedSlice.tags.join(', ')}'}',
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildVisualCatalog(BuildContext context) {
    final filteredSlices = _filteredCatalogSlices();
    final sourcePaths =
        widget.slices
            .map((slice) => slice.sourceImagePath)
            .toSet()
            .toList(growable: false)
          ..sort();
    final sliceCountBySourcePath = <String, int>{};
    for (final slice in widget.slices) {
      sliceCountBySourcePath.update(
        slice.sourceImagePath,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return EditorVisualCatalogLayout(
      searchController: _controller,
      searchKey:
          widget.fieldKey ??
          ValueKey<String>('${widget.optionKeyPrefix}_search'),
      searchLabel: widget.labelText,
      searchHint: widget.hintText,
      clearSearchKey: ValueKey<String>(
        '${widget.optionKeyPrefix}_clear_search',
      ),
      clearSearchTooltip: 'Clear atlas-slice search',
      filters: <Widget>[
        if (widget.showUsageFilters) ...<Widget>[
          ChoiceChip(
            key: ValueKey<String>('${widget.optionKeyPrefix}_usage_all'),
            label: const Text('All'),
            selected: _usageFilter == _AtlasSliceUsageFilter.all,
            onSelected: (_) =>
                setState(() => _usageFilter = _AtlasSliceUsageFilter.all),
          ),
          ChoiceChip(
            key: ValueKey<String>('${widget.optionKeyPrefix}_usage_unused'),
            avatar: const Icon(Icons.fiber_new_outlined, size: 18),
            label: const Text('Unused'),
            selected: _usageFilter == _AtlasSliceUsageFilter.unused,
            onSelected: (_) =>
                setState(() => _usageFilter = _AtlasSliceUsageFilter.unused),
          ),
          ChoiceChip(
            key: ValueKey<String>('${widget.optionKeyPrefix}_usage_used'),
            avatar: const Icon(Icons.link, size: 18),
            label: const Text('Used'),
            selected: _usageFilter == _AtlasSliceUsageFilter.used,
            onSelected: (_) =>
                setState(() => _usageFilter = _AtlasSliceUsageFilter.used),
          ),
        ],
        if (sourcePaths.length > 1)
          _AtlasSourceExplorer(
            key: ValueKey<String>('${widget.optionKeyPrefix}_source_filter'),
            sourcePaths: sourcePaths,
            sliceCountBySourcePath: sliceCountBySourcePath,
            selectedSourcePath: _sourcePathFilter,
            onSelected: (sourcePath) =>
                setState(() => _sourcePathFilter = sourcePath),
          ),
      ],
      countKey: ValueKey<String>('${widget.optionKeyPrefix}_count'),
      countLabel:
          '${filteredSlices.length} of ${widget.slices.length} atlas slices',
      gridKey: ValueKey<String>('${widget.optionKeyPrefix}_grid'),
      emptyKey: ValueKey<String>('${widget.optionKeyPrefix}_empty'),
      emptyMessage: widget.slices.isEmpty
          ? widget.emptyStateMessage
          : 'No atlas slices match the current search and filters.',
      itemCount: filteredSlices.length,
      itemBuilder: (context, index) {
        final slice = filteredSlices[index];
        final prefabIds = _prefabOwnerIds(slice.id);
        final usageDescription = _usageDescription(prefabIds);
        return EditorVisualCatalogCard(
          key: ValueKey<String>('${widget.optionKeyPrefix}_card_${slice.id}'),
          semanticsLabel:
              '${slice.id}, ${slice.width} by ${slice.height} pixels, '
              '$usageDescription',
          tooltipMessage:
              '${slice.id}\n'
              '${slice.width}x${slice.height} px · '
              '${p.basename(slice.sourceImagePath)}\n'
              '${slice.tags.isEmpty ? 'No tags' : 'Tags: ${slice.tags.join(', ')}'}\n'
              '$usageDescription',
          selected: slice.id == widget.selectedSliceId,
          enabled: true,
          preview: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AtlasRegionPreviewTile(
                key: ValueKey<String>(
                  '${widget.optionPreviewKeyPrefix}_${slice.id}',
                ),
                imageCache: _previewImageCache,
                workspaceRootPath: widget.workspaceRootPath,
                sourceImagePath: slice.sourceImagePath,
                region: _regionFor(slice),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: _AtlasSliceUsageBadge(prefabCount: prefabIds.length),
              ),
            ],
          ),
          title: slice.id,
          subtitle: '${slice.width}x${slice.height} · $usageDescription',
          onTap: () => widget.onSelectedSliceChanged(slice.id),
        );
      },
      onSearchSubmitted: () {
        if (filteredSlices.isNotEmpty) {
          widget.onSelectedSliceChanged(filteredSlices.first.id);
        }
      },
      gridHeight: widget.gridHeight,
    );
  }

  List<AtlasSliceDef> _filteredCatalogSlices() {
    final query = _controller.text.trim().toLowerCase();
    final selectedSlice = _selectedSlice;
    final filtered =
        widget.slices
            .where((slice) {
              final used = _prefabOwnerIds(slice.id).isNotEmpty;
              if (_usageFilter == _AtlasSliceUsageFilter.used && !used) {
                return false;
              }
              if (_usageFilter == _AtlasSliceUsageFilter.unused && used) {
                return false;
              }
              if (_sourcePathFilter != null &&
                  slice.sourceImagePath != _sourcePathFilter) {
                return false;
              }
              return query.isEmpty || _matchesQuery(slice, query);
            })
            .toList(growable: false)
          ..sort((a, b) => _compareOptions(a, b, selectedSlice));
    return filtered;
  }

  Iterable<AtlasSliceDef> _buildOptions(TextEditingValue textEditingValue) {
    final query = textEditingValue.text.trim().toLowerCase();
    final selectedSlice = _selectedSlice;
    final candidates = query.isEmpty
        ? widget.slices
        : widget.slices.where((slice) => _matchesQuery(slice, query));
    final optionList = candidates.toList(growable: false)
      ..sort((a, b) => _compareOptions(a, b, selectedSlice));
    return optionList;
  }

  bool _matchesDefaultScope(AtlasSliceDef slice) {
    if (widget.defaultScopeTags.isEmpty) {
      return true;
    }
    final normalizedTags = slice.tags.map((tag) => tag.toLowerCase()).toSet();
    for (final scopeTag in widget.defaultScopeTags) {
      if (normalizedTags.contains(scopeTag.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool _matchesQuery(AtlasSliceDef slice, String query) {
    final haystack = _searchText(slice);
    final tokens = query
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return true;
    }
    for (final token in tokens) {
      if (!haystack.contains(token)) {
        return false;
      }
    }
    return true;
  }

  int _compareOptions(
    AtlasSliceDef a,
    AtlasSliceDef b,
    AtlasSliceDef? selectedSlice,
  ) {
    if (selectedSlice != null) {
      final aSelected = a.id == selectedSlice.id;
      final bSelected = b.id == selectedSlice.id;
      if (aSelected != bSelected) {
        return aSelected ? -1 : 1;
      }
    }
    final aScoped = _matchesDefaultScope(a);
    final bScoped = _matchesDefaultScope(b);
    if (aScoped != bScoped) {
      return aScoped ? -1 : 1;
    }
    return a.id.compareTo(b.id);
  }

  String _searchText(AtlasSliceDef slice) {
    final prefabIds = _prefabOwnerIds(slice.id);
    return [
      slice.id,
      slice.sourceImagePath,
      '${slice.width}x${slice.height}',
      ...slice.tags,
      ...prefabIds,
      prefabIds.isEmpty ? 'unused' : 'used',
    ].join(' ').toLowerCase();
  }

  List<String> _prefabOwnerIds(String sliceId) =>
      widget.prefabOwnerIdsBySliceId[sliceId] ?? const <String>[];

  String _usageDescription(List<String> prefabIds) {
    if (prefabIds.isEmpty) return 'Unused';
    if (prefabIds.length == 1) return 'Used by ${prefabIds.single}';
    return 'Used by ${prefabIds.length} prefabs: ${prefabIds.join(', ')}';
  }

  String _sliceSubtitle(AtlasSliceDef slice) {
    final tagText = slice.tags.isEmpty ? 'no tags' : slice.tags.join(', ');
    return '${slice.width}x${slice.height} px · '
        '${p.basename(slice.sourceImagePath)} · '
        'tags=$tagText';
  }

  bool _containsSliceId(List<AtlasSliceDef> slices, String? sliceId) {
    if (sliceId == null || sliceId.isEmpty) {
      return false;
    }
    for (final slice in slices) {
      if (slice.id == sliceId) {
        return true;
      }
    }
    return false;
  }

  void _handleOptionSelected(AtlasSliceDef slice) {
    _controller.value = TextEditingValue(
      text: slice.id,
      selection: TextSelection.collapsed(offset: slice.id.length),
    );
    widget.onSelectedSliceChanged(slice.id);
  }

  void _handleSubmitted() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      _clearSelection();
      return;
    }
    AtlasSliceDef? exactMatch;
    for (final slice in widget.slices) {
      if (slice.id.toLowerCase() == raw.toLowerCase()) {
        exactMatch = slice;
        break;
      }
    }
    final matches = _buildOptions(TextEditingValue(text: raw))
        .toList(growable: false);
    exactMatch ??= matches.isEmpty ? null : matches.first;
    if (exactMatch == null) {
      return;
    }
    _handleOptionSelected(exactMatch);
    _focusNode.unfocus();
  }

  void _clearSelection() {
    _controller.clear();
    widget.onSelectedSliceChanged(null);
    _focusNode.unfocus();
  }

  void _syncTextFromSelection({bool force = false}) {
    if (_focusNode.hasFocus && !force) {
      return;
    }
    final nextText = _selectedSlice?.id ?? '';
    if (_controller.text == nextText) {
      return;
    }
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  AtlasPixelRect _regionFor(AtlasSliceDef slice) => AtlasPixelRect(
    x: slice.x,
    y: slice.y,
    width: slice.width,
    height: slice.height,
  );
}

const String _allSourcePathsValue = '__all_atlas_sources__';

enum _AtlasSliceUsageFilter { all, unused, used }

class _AtlasSourceExplorer extends StatelessWidget {
  const _AtlasSourceExplorer({
    super.key,
    required this.sourcePaths,
    required this.sliceCountBySourcePath,
    required this.selectedSourcePath,
    required this.onSelected,
  });

  final List<String> sourcePaths;
  final Map<String, int> sliceCountBySourcePath;
  final String? selectedSourcePath;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final pathsByDirectory = <String, List<String>>{};
    for (final sourcePath in sourcePaths) {
      pathsByDirectory
          .putIfAbsent(p.dirname(sourcePath), () => <String>[])
          .add(sourcePath);
    }
    final directories = pathsByDirectory.keys.toList(growable: false)..sort();
    final totalSlices = sliceCountBySourcePath.values.fold<int>(
      0,
      (total, count) => total + count,
    );
    final selectedLabel = selectedSourcePath == null
        ? 'All atlas sources'
        : p.basename(selectedSourcePath!);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: PopupMenuButton<String>(
        tooltip: 'Browse atlas sources',
        initialValue: selectedSourcePath ?? _allSourcePathsValue,
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(
          minWidth: 300,
          maxWidth: 430,
          maxHeight: 480,
        ),
        onSelected: (value) =>
            onSelected(value == _allSourcePathsValue ? null : value),
        itemBuilder: (context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            key: const ValueKey<String>('atlas_source_explorer_all'),
            value: _allSourcePathsValue,
            child: _AtlasSourceExplorerRow(
              icon: Icons.inventory_2_outlined,
              label: 'All atlas sources',
              sliceCount: totalSlices,
              selected: selectedSourcePath == null,
            ),
          ),
          const PopupMenuDivider(),
          for (final directory in directories) ...<PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              key: ValueKey<String>('atlas_source_explorer_folder_$directory'),
              enabled: false,
              height: 36,
              child: _AtlasSourceExplorerRow(
                icon: Icons.folder_outlined,
                label: p.basename(directory),
                sliceCount: pathsByDirectory[directory]!.fold<int>(
                  0,
                  (total, sourcePath) =>
                      total + (sliceCountBySourcePath[sourcePath] ?? 0),
                ),
              ),
            ),
            for (final sourcePath in pathsByDirectory[directory]!)
              PopupMenuItem<String>(
                key: ValueKey<String>('atlas_source_explorer_file_$sourcePath'),
                value: sourcePath,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Tooltip(
                    message: sourcePath,
                    child: _AtlasSourceExplorerRow(
                      icon: Icons.image_outlined,
                      label: p.basename(sourcePath),
                      sliceCount: sliceCountBySourcePath[sourcePath] ?? 0,
                      selected: selectedSourcePath == sourcePath,
                    ),
                  ),
                ),
              ),
          ],
        ],
        child: InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Atlas source',
            isDense: true,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.folder_open_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(selectedLabel, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtlasSourceExplorerRow extends StatelessWidget {
  const _AtlasSourceExplorerRow({
    required this.icon,
    required this.label,
    required this.sliceCount,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final int sliceCount;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      Text('$sliceCount', style: Theme.of(context).textTheme.bodySmall),
      if (selected) ...<Widget>[
        const SizedBox(width: 8),
        Icon(
          Icons.check,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    ],
  );
}

class _AtlasSliceUsageBadge extends StatelessWidget {
  const _AtlasSliceUsageBadge({required this.prefabCount});

  final int prefabCount;

  @override
  Widget build(BuildContext context) {
    final used = prefabCount > 0;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: used
            ? colorScheme.tertiaryContainer.withValues(alpha: 0.94)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: used ? colorScheme.tertiary : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(used ? Icons.link : Icons.fiber_new_outlined, size: 13),
            const SizedBox(width: 3),
            Text(
              used
                  ? prefabCount == 1
                        ? 'Used'
                        : 'Used $prefabCount'
                  : 'Unused',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
