import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import '../../shared/editor_inline_id_form.dart';
import '../../shared/editor_section_card.dart';
import '../../shared/editor_ui_tokens.dart';
import 'prefab_v3_owner_form.dart';

/// Inline creation section whose values remain local until the parent accepts.
class PrefabOwnerCreateSection extends StatelessWidget {
  const PrefabOwnerCreateSection({
    super.key,
    required this.formDocument,
    required this.workspaceRootPath,
    required this.formKey,
    required this.canCreate,
    required this.isExpanded,
    required this.isDirty,
    required this.onExpansionChanged,
    required this.onDirtyChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final PrefabV3Document formDocument;
  final String workspaceRootPath;
  final GlobalKey<PrefabV3OwnerFormState> formKey;
  final bool canCreate;
  final bool isExpanded;
  final bool isDirty;
  final ValueChanged<bool> onExpansionChanged;
  final ValueChanged<bool> onDirtyChanged;
  final VoidCallback onCancel;
  final PrefabV3OwnerFormSubmit onSubmit;

  @override
  Widget build(BuildContext context) => EditorSectionCard(
    key: const ValueKey<String>('prefab_v3_owner_create_section'),
    title: 'Create prefab',
    description: canCreate
        ? 'Create from an authored atlas slice or platform module.'
        : 'Create an atlas slice or platform module first.',
    collapsible: !isDirty,
    initiallyExpanded: false,
    expanded: isExpanded || isDirty,
    expansionKey: const ValueKey<String>(
      'prefab_v3_owner_create_section_toggle',
    ),
    onExpansionChanged: onExpansionChanged,
    child: canCreate
        ? PrefabV3OwnerForm(
            key: formKey,
            document: formDocument,
            workspaceRootPath: workspaceRootPath,
            autofocusId: true,
            submitLabel: 'Create prefab',
            submitKey: const ValueKey<String>(
              'prefab_v3_owner_inline_create_apply',
            ),
            cancelKey: const ValueKey<String>(
              'prefab_v3_owner_inline_create_cancel',
            ),
            onDirtyChanged: onDirtyChanged,
            onCancel: onCancel,
            onSubmit: onSubmit,
          )
        : const Text('No visual source is currently available for a prefab.'),
  );
}

/// Row-local Prefab metadata and lifecycle editor presentation.
class PrefabOwnerEditDetails extends StatelessWidget {
  const PrefabOwnerEditDetails({
    super.key,
    required this.document,
    required this.currentPrefab,
    required this.source,
    required this.workspaceRootPath,
    required this.editFormKey,
    required this.renameFormKey,
    required this.isDirty,
    required this.renameActive,
    required this.renameValidator,
    required this.onEditCollision,
    required this.onBeginRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onDirtyChanged,
    required this.onCancelRename,
    required this.onRename,
    required this.onCancelEdit,
    required this.onApplyEdit,
  });

  final PrefabV3Document document;
  final PrefabV3Def currentPrefab;
  final PrefabV3Def source;
  final String workspaceRootPath;
  final GlobalKey<PrefabV3OwnerFormState> editFormKey;
  final GlobalKey<EditorInlineIdFormState> renameFormKey;
  final bool isDirty;
  final bool renameActive;
  final EditorInlineIdValidator renameValidator;
  final VoidCallback onEditCollision;
  final VoidCallback onBeginRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<bool> onDirtyChanged;
  final VoidCallback onCancelRename;
  final EditorInlineIdSubmit onRename;
  final VoidCallback onCancelEdit;
  final PrefabV3OwnerFormSubmit onApplyEdit;

  bool get _lifecycleEnabled => !isDirty && !renameActive;

  @override
  Widget build(BuildContext context) {
    final impact = document.downstreamImpacts
        .where((entry) => entry.prefabKey == source.prefabKey)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Edit ${currentPrefab.id}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: EditorUiTokens.controlGap),
        Text(
          'prefabKey: ${source.prefabKey} · revision ${source.revision}\n'
          '${source.visualSource.type.jsonValue}:${source.sourceRefId} · '
          '${source.collisionShapes.length} collision shape(s) · '
          '${impact?.placementCount ?? 0} downstream placement(s)',
        ),
        const SizedBox(height: EditorUiTokens.sectionGap),
        Wrap(
          spacing: EditorUiTokens.controlGap,
          runSpacing: EditorUiTokens.controlGap,
          children: <Widget>[
            if (_canAuthorCollision(source))
              Tooltip(
                message: source.collisionShapes.isEmpty
                    ? 'Set up collision for ${source.id}.'
                    : 'Edit collision for ${source.id}.',
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('prefab_v3_owner_edit_collision'),
                  onPressed: _lifecycleEnabled ? onEditCollision : null,
                  icon: const Icon(Icons.border_style_outlined),
                  label: Text(
                    source.collisionShapes.isEmpty
                        ? 'Set up collision'
                        : 'Edit collision',
                  ),
                ),
              ),
            Tooltip(
              message: 'Rename ${source.id} while preserving its prefab key.',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('prefab_v3_owner_rename'),
                onPressed: _lifecycleEnabled ? onBeginRename : null,
                icon: const Icon(Icons.drive_file_rename_outline),
                label: const Text('Rename'),
              ),
            ),
            Tooltip(
              message: 'Duplicate ${source.id} with a new stable prefab key.',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('prefab_v3_owner_duplicate'),
                onPressed: _lifecycleEnabled ? onDuplicate : null,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Duplicate'),
              ),
            ),
            Tooltip(
              message: 'Delete ${source.id} after reviewing its references.',
              child: OutlinedButton.icon(
                key: const ValueKey<String>('prefab_v3_owner_delete'),
                onPressed: _lifecycleEnabled ? onDelete : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
        const SizedBox(height: EditorUiTokens.sectionGap),
        if (renameActive)
          EditorInlineIdForm(
            key: renameFormKey,
            initialValue: source.id,
            fieldKey: const ValueKey<String>('prefab_v3_inline_rename_id'),
            submitKey: const ValueKey<String>('prefab_v3_inline_rename_apply'),
            cancelKey: const ValueKey<String>('prefab_v3_inline_rename_cancel'),
            submitLabel: 'Rename prefab',
            helperText: 'The stable prefab key is preserved.',
            validator: renameValidator,
            onDirtyChanged: onDirtyChanged,
            onCancel: onCancelRename,
            onSubmit: onRename,
          )
        else
          PrefabV3OwnerForm(
            key: editFormKey,
            document: document,
            workspaceRootPath: workspaceRootPath,
            prefab: source,
            submitLabel: 'Apply changes',
            submitKey: ValueKey<String>(
              'prefab_v3_owner_inline_apply_${source.prefabKey}',
            ),
            cancelKey: ValueKey<String>(
              'prefab_v3_owner_inline_cancel_${source.prefabKey}',
            ),
            onDirtyChanged: onDirtyChanged,
            onCancel: onCancelEdit,
            onSubmit: onApplyEdit,
          ),
      ],
    );
  }
}

bool _canAuthorCollision(PrefabV3Def prefab) =>
    prefab.kind == PrefabKind.obstacle || prefab.kind == PrefabKind.platform;
