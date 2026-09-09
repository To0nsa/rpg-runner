import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';
import '../../shared/editor_inline_id_form.dart';
import '../../shared/editor_list_card.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_ui_tokens.dart';
import 'chunk_owner_preview.dart';
import 'chunk_owner_order.dart';
import 'chunk_v2_owner_form.dart';

/// Existing-owner list with previews and a row-local editor slot.
class ChunkOwnerListSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final chunks = List<ChunkV2FileData>.of(scene.chunks)
      ..sort(compareChunkOwners);
    return EditorSectionCard(
      key: const ValueKey<String>('chunk_owner_section'),
      title: 'Existing chunk owners',
      collapsible: true,
      initiallyExpanded: false,
      expansionKey: const ValueKey<String>('chunk_owner_section_toggle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (chunks.isEmpty)
            const Text(
              'No chunk owners remain in this level. Creation requires one '
              'existing owner to provide locked tile size and dimensions.',
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
                    tooltip: 'Edit ${chunk.id}',
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
                  chunk.id,
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
        'Edit ${currentChunk.id}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Text(
        'chunkKey: ${source.chunkKey} · revision ${source.revision}\n'
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
            message: 'Duplicate ${source.id} with a new stable chunk key.',
            child: OutlinedButton.icon(
              key: const ValueKey<String>('chunk_v2_owner_duplicate'),
              onPressed: _lifecycleEnabled ? onDuplicate : null,
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate'),
            ),
          ),
          Tooltip(
            message: 'Delete ${source.id} and its authored composition.',
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
