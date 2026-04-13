import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../../prefabs/models/models.dart';
import '../../../shared/atlas_slice_preview_tile.dart';
import '../../../shared/editor_scene_view_utils.dart';
import 'prefab_editor_ui_tokens.dart';

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

  @override
  State<PrefabEditorAtlasSliceSelector> createState() =>
      _PrefabEditorAtlasSliceSelectorState();
}

class _PrefabEditorAtlasSliceSelectorState
    extends State<PrefabEditorAtlasSliceSelector> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final EditorUiImageCache _previewImageCache = EditorUiImageCache();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleControllerChanged);
    _syncTextFromSelection(force: true);
  }

  @override
  void didUpdateWidget(covariant PrefabEditorAtlasSliceSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSliceId != widget.selectedSliceId ||
        oldWidget.slices != widget.slices) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.slices.isEmpty) {
      return Text(widget.emptyStateMessage);
    }

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
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: widget.labelText,
                    hintText: widget.hintText,
                    suffixIcon:
                        textEditingController.text.trim().isEmpty &&
                            widget.selectedSliceId == null
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
                    key: ValueKey<String>(
                      '${widget.optionKeyPrefix}_list',
                    ),
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
                        leading: AtlasSlicePreviewTile(
                          key: ValueKey<String>(
                            '${widget.optionPreviewKeyPrefix}_${slice.id}',
                          ),
                          imageCache: _previewImageCache,
                          workspaceRootPath: widget.workspaceRootPath,
                          slice: slice,
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
        const SizedBox(height: PrefabEditorUiTokens.controlGap),
        if (selectedSlice == null)
          Text(scopedHint)
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AtlasSlicePreviewTile(
                key:
                    widget.selectedPreviewKey ??
                    ValueKey<String>(
                      '${widget.optionKeyPrefix}_selected_preview',
                    ),
                imageCache: _previewImageCache,
                workspaceRootPath: widget.workspaceRootPath,
                slice: selectedSlice,
                width: 72,
                height: 56,
              ),
              const SizedBox(width: PrefabEditorUiTokens.rowPreviewGap),
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
    return [
      slice.id,
      slice.sourceImagePath,
      '${slice.width}x${slice.height}',
      ...slice.tags,
    ].join(' ').toLowerCase();
  }

  String _sliceSubtitle(AtlasSliceDef slice) {
    final tagText = slice.tags.isEmpty ? 'no tags' : slice.tags.join(', ');
    return '${slice.width}x${slice.height} px · '
        '${p.basename(slice.sourceImagePath)} · '
        'tags=$tagText';
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
    final matches = _buildOptions(
      TextEditingValue(text: raw),
    ).toList(growable: false);
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
}
