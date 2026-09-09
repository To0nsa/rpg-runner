import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../shared/editor_inline_id_form.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_ui_tokens.dart';
import '../../shared/editor_visual_catalog.dart';
import 'chunk_owner_preview.dart';
import 'chunk_owner_order.dart';
import 'chunk_v2_owner_form.dart';

/// Existing-owner list with previews and a row-local editor slot.
class ChunkOwnerListSection extends StatefulWidget {
  const ChunkOwnerListSection({
    super.key,
    required this.document,
    required this.scene,
    required this.selectedChunk,
    required this.expandedChunk,
    required this.workspaceRootPath,
    required this.expandedPrefabShapeCount,
    required this.onSelected,
    required this.onEdit,
    required this.selectedDetailsBuilder,
  });

  final ChunkV2Document document;
  final ChunkV2Scene scene;
  final ChunkV2FileData? selectedChunk;
  final ChunkV2FileData? expandedChunk;
  final String workspaceRootPath;
  final int Function(String chunkKey) expandedPrefabShapeCount;
  final ValueChanged<ChunkV2FileData> onSelected;
  final ValueChanged<ChunkV2FileData> onEdit;
  final Widget Function(BuildContext context, ChunkV2FileData chunk)
  selectedDetailsBuilder;

  @override
  State<ChunkOwnerListSection> createState() => _ChunkOwnerListSectionState();
}

class _ChunkOwnerListSectionState extends State<ChunkOwnerListSection> {
  late final TextEditingController _searchController;
  String _difficultyFilter = '';
  String _groupFilter = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ChunkOwnerListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_difficultyFilter.isNotEmpty &&
        !widget.scene.chunks.any(
          (chunk) => chunk.difficulty == _difficultyFilter,
        )) {
      _difficultyFilter = '';
    }
    if (_groupFilter.isNotEmpty &&
        !widget.scene.chunks.any(
          (chunk) => chunk.assemblyGroupId == _groupFilter,
        )) {
      _groupFilter = '';
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final scene = widget.scene;
    final selectedChunk = widget.selectedChunk;
    final expandedChunk = widget.expandedChunk;
    final workspaceRootPath = widget.workspaceRootPath;
    final expandedPrefabShapeCount = widget.expandedPrefabShapeCount;
    final onSelected = widget.onSelected;
    final onEdit = widget.onEdit;
    final selectedDetailsBuilder = widget.selectedDetailsBuilder;
    final allChunks = List<ChunkV2FileData>.of(scene.chunks)
      ..sort(compareChunkOwners);
    final chunks = _filteredChunks(allChunks);
    final difficulties =
        allChunks
            .map((chunk) => chunk.difficulty)
            .toSet()
            .toList(growable: false)
          ..sort();
    final groups =
        allChunks
            .map((chunk) => chunk.assemblyGroupId)
            .toSet()
            .toList(growable: false)
          ..sort();
    return EditorSectionCard(
      key: const ValueKey<String>('chunk_owner_section'),
      title: 'Existing chunk owners',
      collapsible: true,
      initiallyExpanded: false,
      expansionKey: const ValueKey<String>('chunk_owner_section_toggle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EditorVisualCatalogControls(
            searchController: _searchController,
            searchKey: const ValueKey<String>('chunk_owner_search'),
            searchLabel: 'Search chunk owners',
            searchHint: 'Chunk key contains…',
            clearSearchKey: const ValueKey<String>('chunk_owner_clear_search'),
            clearSearchTooltip: 'Clear owner search',
            filters: <Widget>[
              SizedBox(
                width: 164,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'chunk_owner_difficulty_filter_$_difficultyFilter',
                  ),
                  initialValue: _difficultyFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All difficulties'),
                    ),
                    for (final difficulty in difficulties)
                      DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(difficulty),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _difficultyFilter = value ?? ''),
                ),
              ),
              SizedBox(
                width: 164,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'chunk_owner_group_filter_$_groupFilter',
                  ),
                  initialValue: _groupFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Group',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All groups'),
                    ),
                    for (final group in groups)
                      DropdownMenuItem<String>(
                        value: group,
                        child: Text(group),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _groupFilter = value ?? ''),
                ),
              ),
              TextButton.icon(
                key: const ValueKey<String>('chunk_owner_clear_filters'),
                onPressed: _hasFilters ? _clearFilters : null,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
            ],
            countKey: const ValueKey<String>('chunk_owner_filter_count'),
            countLabel: '${chunks.length} of ${allChunks.length} owners',
            onSearchSubmitted: () {
              if (chunks.isNotEmpty) onSelected(chunks.first);
            },
          ),
          const SizedBox(height: EditorUiTokens.controlGap),
          if (allChunks.isEmpty)
            const Text(
              'No chunk owners remain in this level. Creation requires one '
              'existing owner to provide locked tile size and dimensions.',
            ),
          if (allChunks.isNotEmpty && chunks.isEmpty)
            const Padding(
              key: ValueKey<String>('chunk_owner_filter_empty'),
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No chunk owners match the current search and filters.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final chunk in chunks) ...<Widget>[
            EditorListCard(
              key: ValueKey<String>('chunk_polygon_owner_${chunk.chunkKey}'),
              isSelected: chunk.chunkKey == selectedChunk?.chunkKey,
              onTap: () => onSelected(chunk),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (document.changedChunkKeys.contains(chunk.chunkKey)) ...[
                    const Tooltip(
                      message: 'Pending geometry changed',
                      child: Icon(Icons.circle, size: 12),
                    ),
                    const SizedBox(width: EditorUiTokens.rowMetadataGap),
                  ],
                  IconButton(
                    key: ValueKey<String>(
                      'chunk_v2_owner_edit_${chunk.chunkKey}',
                    ),
                    tooltip: 'Edit ${chunk.chunkKey}',
                    onPressed: () => onEdit(chunk),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              details: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      key: ValueKey<String>(
                        'chunk_owner_metadata_${chunk.chunkKey}',
                      ),
                      '${chunk.difficulty} · ${chunk.width}×${chunk.height} px · '
                      'rev ${chunk.revision}\n${chunk.status} · '
                      '${chunk.collisionShapes.length} direct · '
                      '${expandedPrefabShapeCount(chunk.chunkKey)} expanded',
                    ),
                  ),
                  const SizedBox(width: EditorUiTokens.rowPreviewGap),
                  ChunkOwnerPreview(
                    key: ValueKey<String>(
                      'chunk_owner_preview_${chunk.chunkKey}',
                    ),
                    workspaceRootPath: workspaceRootPath,
                    chunk: chunk,
                    scene: scene,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  chunk.chunkKey,
                  key: ValueKey<String>('chunk_owner_name_${chunk.chunkKey}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (expandedChunk?.chunkKey == chunk.chunkKey)
              Padding(
                key: ValueKey<String>(
                  'chunk_v2_owner_inline_editor_${chunk.chunkKey}',
                ),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: selectedDetailsBuilder(context, chunk),
              ),
          ],
        ],
      ),
    );
  }

  bool get _hasFilters =>
      _searchController.text.isNotEmpty ||
      _difficultyFilter.isNotEmpty ||
      _groupFilter.isNotEmpty;

  List<ChunkV2FileData> _filteredChunks(List<ChunkV2FileData> chunks) {
    final query = _searchController.text.trim().toLowerCase();
    return chunks
        .where(
          (chunk) =>
              (query.isEmpty || chunk.chunkKey.toLowerCase().contains(query)) &&
              (_difficultyFilter.isEmpty ||
                  chunk.difficulty == _difficultyFilter) &&
              (_groupFilter.isEmpty || chunk.assemblyGroupId == _groupFilter),
        )
        .toList(growable: false);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _difficultyFilter = '';
      _groupFilter = '';
    });
  }

  void _handleSearchChanged() => setState(() {});
}

/// Inline creation section using an existing owner as dimension template.
class ChunkOwnerCreateSection extends StatelessWidget {
  const ChunkOwnerCreateSection({
    super.key,
    required this.formKey,
    required this.template,
    required this.isExpanded,
    required this.isDirty,
    required this.onExpansionChanged,
    required this.validator,
    required this.onDirtyChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final GlobalKey<EditorInlineIdFormState> formKey;
  final ChunkV2FileData? template;
  final bool isExpanded;
  final bool isDirty;
  final ValueChanged<bool> onExpansionChanged;
  final EditorInlineIdValidator validator;
  final ValueChanged<bool> onDirtyChanged;
  final VoidCallback onCancel;
  final EditorInlineIdSubmit onSubmit;

  @override
  Widget build(BuildContext context) => EditorSectionCard(
    key: const ValueKey<String>('chunk_owner_create_section'),
    title: 'Create chunk owner',
    description: template == null
        ? 'Creation needs an existing owner in this level to provide locked dimensions.'
        : 'Creates an empty deprecated owner at '
              '${template!.width}×${template!.height} px with '
              '${template!.tileSize} px tiles.',
    collapsible: !isDirty,
    initiallyExpanded: false,
    expanded: isExpanded || isDirty,
    expansionKey: const ValueKey<String>('chunk_owner_create_section_toggle'),
    onExpansionChanged: onExpansionChanged,
    child: template == null
        ? const Text(
            'Undo an owner deletion or switch to a level with an existing '
            'dimension template.',
          )
        : EditorInlineIdForm(
            key: formKey,
            initialValue: '',
            fieldKey: const ValueKey<String>('chunk_v2_inline_create_id'),
            submitKey: const ValueKey<String>('chunk_v2_inline_create_apply'),
            cancelKey: const ValueKey<String>('chunk_v2_inline_create_cancel'),
            submitLabel: 'Create owner',
            fieldLabel: 'Chunk key',
            helperText: 'The owner starts deprecated with locked dimensions and an empty composition.',
            validator: validator,
            onDirtyChanged: onDirtyChanged,
            onCancel: onCancel,
            onSubmit: onSubmit,
          ),
  );
}

/// Row-local Chunk metadata and lifecycle editor presentation.
class ChunkOwnerEditDetails extends StatelessWidget {
  const ChunkOwnerEditDetails({
    super.key,
    required this.document,
    required this.currentChunk,
    required this.source,
    required this.editFormKey,
    required this.isDirty,
    required this.onDuplicate,
    required this.onDelete,
    required this.onDirtyChanged,
    required this.onCancelEdit,
    required this.onApplyEdit,
  });

  final ChunkV2Document document;
  final ChunkV2FileData currentChunk;
  final ChunkV2FileData source;
  final GlobalKey<ChunkV2OwnerFormState> editFormKey;
  final bool isDirty;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<bool> onDirtyChanged;
  final VoidCallback onCancelEdit;
  final ChunkV2OwnerFormSubmit onApplyEdit;

  bool get _lifecycleEnabled => !isDirty;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        'Edit ${currentChunk.chunkKey}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Text(
        'revision ${source.revision}\n'
        '${source.width}×${source.height} px · tile ${source.tileSize} px · '
        '${source.collisionShapes.length} shape(s) · '
        '${source.prefabs.length} prefab(s) · ${source.markers.length} marker(s)',
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          Tooltip(
            message: 'Duplicate ${source.chunkKey} with a new chunk key.',
            child: OutlinedButton.icon(
              key: const ValueKey<String>('chunk_v2_owner_duplicate'),
              onPressed: _lifecycleEnabled ? onDuplicate : null,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            ),
          ),
          Tooltip(
            message: 'Delete ${source.chunkKey} and its authored composition.',
            child: OutlinedButton.icon(
              key: const ValueKey<String>('chunk_v2_owner_delete'),
              onPressed: _lifecycleEnabled ? onDelete : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ChunkV2OwnerForm(
        key: editFormKey,
        document: document,
        chunk: source,
        submitKey: ValueKey<String>(
          'chunk_v2_owner_inline_apply_${source.chunkKey}',
        ),
        cancelKey: ValueKey<String>(
          'chunk_v2_owner_inline_cancel_${source.chunkKey}',
        ),
        onDirtyChanged: onDirtyChanged,
        onCancel: onCancelEdit,
        onSubmit: onApplyEdit,
      ),
    ],
  );
}
