import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:game_presentation/item_icon_ids.dart';
import 'package:game_presentation/canonical_item_icon.dart';
import 'package:runner_content_pipeline/item_source.dart';
import 'package:tool_ui/tool_ui.dart';

import '../../../domain/authoring_types.dart';
import '../../../items/item_domain_plugin.dart';
import '../../../session/editor_session_controller.dart';
import '../shared/editor_page_local_draft_state.dart';
import '../shared/editor_page_navigation_state.dart';
import '../shared/editor_pending_changes_dialog.dart';
import '../shared/game_asset_bundle.dart';
import 'item_fields_form.dart';

final class ItemsLocation extends EditorPageLocation {
  const ItemsLocation(this.itemId);
  final String? itemId;
  @override
  AuthoringDocument restoreDocumentSelection(
    AuthoringDomainPlugin plugin,
    AuthoringDocument document,
  ) =>
      document is ItemDocument &&
          document.catalog.items.any((i) => i.id == itemId)
      ? plugin.applyEdit(
          document,
          AuthoringCommand(
            kind: ItemDomainPlugin.select,
            payload: {'id': itemId},
          ),
        )
      : document;
}

/// Item form buffers participate in the shell's Save, navigation and Undo guards.
/// The page never writes source files or generated runtime catalogs itself.
class ItemsPage extends StatefulWidget {
  const ItemsPage({
    super.key,
    required this.controller,
    this.initialLocation,
    this.onShellStateChanged,
  });
  final EditorSessionController controller;
  final ItemsLocation? initialLocation;
  final VoidCallback? onShellStateChanged;
  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage>
    implements
        EditorPageNavigationState,
        EditorPageLocalDraftState,
        EditorPageSaveHandler,
        EditorPageSessionShortcutHandler {
  final _form = GlobalKey<FormState>();
  final _assets = EditorGameAssetBundle();
  final _panels = ToolThreePanelController();
  ItemDocument? _doc;
  ItemSource? _original;
  Map<String, dynamic>? _draft;
  String? _error;
  String _search = '';
  int _formRevision = 0;
  @override
  EditorPageLocation get navigationLocation => ItemsLocation(_doc?.selectedId);
  @override
  bool get hasLocalDraftChanges =>
      _draft != null && jsonEncode(_draft) != jsonEncode(_original?.toJson());
  @override
  bool get canSaveEditorPage =>
      !widget.controller.isExporting &&
      (hasLocalDraftChanges || widget.controller.pendingChanges.hasChanges);
  @override
  bool get canHandleUndoSessionShortcut =>
      hasLocalDraftChanges || widget.controller.canUndo;
  @override
  bool get canHandleRedoSessionShortcut =>
      !hasLocalDraftChanges && widget.controller.canRedo;
  @override
  bool handleUndoSessionShortcut() {
    if (hasLocalDraftChanges) {
      setState(_reset);
      widget.onShellStateChanged?.call();
    } else {
      widget.controller.undo();
    }
    return true;
  }

  @override
  bool handleRedoSessionShortcut() {
    widget.controller.redo();
    return true;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _sync();
    if (_doc == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.controller.isLoading) {
          widget.controller.loadWorkspace();
        }
      });
    }
  }

  @override
  void dispose() {
    _panels.dispose();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _reset() {
    _original = _doc?.selected;
    _draft = _original == null
        ? null
        : jsonDecode(jsonEncode(_original!.toJson())) as Map<String, dynamic>;
    _error = null;
    _formRevision++;
  }

  void _sync() {
    final next = widget.controller.document;
    if (next is ItemDocument && !identical(next, _doc)) {
      _doc = next;
      _reset();
    }
  }

  void _changed() {
    if (mounted) setState(_sync);
  }

  void _edit() {
    setState(() => _error = null);
    widget.onShellStateChanged?.call();
  }

  bool _accept() {
    if (!hasLocalDraftChanges) return true;
    if (!(_form.currentState?.validate() ?? false)) return false;
    try {
      final item = ItemSource.decode(_draft);
      widget.controller.applyCommand(
        AuthoringCommand(
          kind: ItemDomainPlugin.replace,
          payload: {
            'id': _original!.id,
            'expected': _original!.toJson(),
            'item': item.toJson(),
          },
        ),
      );
      // Busy/recovery gates can decline a command; retain input until accepted.
      if (widget.controller.document is ItemDocument &&
          jsonEncode(
                (widget.controller.document as ItemDocument).selected?.toJson(),
              ) ==
              jsonEncode(item.toJson())) {
        return true;
      }
      setState(
        () => _error = 'The edit was rejected. Review validation and reload if the source changed.',
      );
    } on Object catch (e) {
      setState(() => _error = '$e');
    }
    return false;
  }

  @override
  Future<EditorPageSaveResult> saveEditorPage() async {
    if (!_accept()) return EditorPageSaveResult.blocked;
    await widget.controller.exportDirectWrite();
    return EditorPageSaveResult.fromSession(widget.controller);
  }

  Future<bool> _resolveDraft() async {
    if (!hasLocalDraftChanges) return true;
    final action = await showEditorPendingChangesDialog(
      context: context,
      dialogKey: const ValueKey('item_pending'),
      title: 'Unsaved item changes',
      content: const Text('Save the visible item before changing selection?'),
      cancelKey: const ValueKey('item_cancel'),
      discardKey: const ValueKey('item_discard'),
      saveKey: const ValueKey('item_save'),
    );
    if (action == EditorPendingChangesAction.save) {
      return (await saveEditorPage()).permitsDeparture;
    }
    if (action == EditorPendingChangesAction.discard) {
      setState(_reset);
      return true;
    }
    return false;
  }

  Future<void> _select(String id) async {
    if (!await _resolveDraft() || !mounted) return;
    widget.controller.applyPresentationCommand(
      AuthoringCommand(kind: ItemDomainPlugin.select, payload: {'id': id}),
    );
    _panels.revealPanel(1);
  }

  Future<void> _create({bool duplicate = false}) async {
    if (!await _resolveDraft() || !mounted) return;
    final doc = _doc!;
    if (duplicate) {
      widget.controller.applyCommand(
        AuthoringCommand(
          kind: ItemDomainPlugin.duplicate,
          payload: {
            'category': doc.selected!.category.name,
            'templateId': doc.selectedId,
          },
        ),
      );
      _panels.revealPanel(1);
      return;
    }
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateItemDialog(
        existingIds: {
          ...doc.catalog.items.map((i) => i.id),
          ...doc.catalog.internalProjectiles.values,
        },
      ),
    );
    if (result != null && mounted) {
      widget.controller.applyCommand(
        AuthoringCommand(kind: ItemDomainPlugin.create, payload: result),
      );
      _panels.revealPanel(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc, draft = _draft;
    if (doc == null) {
      return const Center(child: Text('Load an item authoring workspace.'));
    }
    final library = ToolPanelCard(
      title: 'Items',
      bodyMode: ToolPanelBodyMode.scrollable,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Search items'),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _create(),
                icon: const Icon(Icons.add),
                label: const Text('Create item'),
              ),
              TextButton.icon(
                onPressed: doc.selected == null
                    ? null
                    : () => _create(duplicate: true),
                icon: const Icon(Icons.copy),
                label: const Text('Duplicate'),
              ),
            ],
          ),
          for (final item in doc.catalog.items.where(
            (i) => '${i.id} ${i.names.values.join(' ')}'.toLowerCase().contains(
              _search,
            ),
          ))
            ListTile(
              selected: item.id == doc.selectedId,
              title: Text(item.names['en']!),
              subtitle: Text('${item.category.name} · ${item.id}'),
              onTap: () => _select(item.id),
            ),
        ],
      ),
    );
    final editor = ToolPanelCard(
      title: _original?.names['en'] ?? 'Item',
      bodyMode: ToolPanelBodyMode.scrollable,
      child: draft == null
          ? const Text('Select an item.')
          : Form(
              key: _form,
              child: Column(
                key: ValueKey(_formRevision),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ID: ${draft['id']} · ordinal ${draft['ordinal']} (read-only)',
                  ),
                  const Text(
                    'Save writes source. Build compiles items; restart/rebuild tools to refresh shared pickers.',
                  ),
                  if (hasLocalDraftChanges) const Text('Unsaved form changes'),
                  if (_error != null)
                    SelectableText(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  for (final locale in ['en', 'fr'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextFormField(
                        key: ValueKey('item_name_$locale'),
                        initialValue: draft['name'][locale] as String,
                        decoration: InputDecoration(
                          labelText: locale == 'en'
                              ? 'English name'
                              : 'French name',
                        ),
                        onChanged: (v) {
                          draft['name'][locale] = v;
                          _edit();
                        },
                        validator: (v) =>
                            v == null || v.trim().isEmpty || v.length > 120
                            ? 'Enter a translated name of 1–120 characters.'
                            : null,
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('icon_${draft['icon']}'),
                    initialValue: draft['icon'] as String,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Canonical icon',
                    ),
                    items: [
                      for (final icon
                          in canonicalItemIconChoices[_original!
                              .category
                              .name]!)
                        DropdownMenuItem(value: icon, child: Text(icon)),
                    ],
                    onChanged: (v) {
                      draft['icon'] = v;
                      _edit();
                    },
                  ),
                  if (_original!.category == ItemCategory.projectile)
                    DropdownButtonFormField<String>(
                      key: ValueKey('render_${draft['renderAs']}'),
                      initialValue: draft['renderAs'] as String,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText:
                            'Existing projectile / muzzle artwork profile',
                      ),
                      items: [
                        for (final profile
                            in canonicalItemIconChoices['projectile']!)
                          DropdownMenuItem(
                            value: profile,
                            child: Text(profile),
                          ),
                      ],
                      onChanged: (v) {
                        draft['renderAs'] = v;
                        _edit();
                      },
                    ),
                  ItemFieldsForm(
                    values: draft['data'] as Map<String, dynamic>,
                    fields: itemFields(_original!.category),
                    onChanged: _edit,
                  ),
                ],
              ),
            ),
    );
    return DefaultAssetBundle(
      bundle: _assets,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ToolThreePanelLayout(
          controller: _panels,
          firstLabel: 'Library',
          secondLabel: 'Item',
          thirdLabel: 'Eligibility & art',
          first: library,
          second: editor,
          third: ToolPanelCard(
            title: 'Eligibility & art',
            bodyMode: ToolPanelBodyMode.scrollable,
            child: draft == null
                ? const Text('Select an item.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CanonicalItemIcon(
                        category: _original!.category.name,
                        icon: draft['icon'] as String,
                        size: 96,
                      ),
                      const SizedBox(height: 12),
                      Text(_eligibility(draft)),
                      const SizedBox(height: 12),
                      const Text(
                        'Gear ownership is account-wide; equipment eligibility is character-specific. Projectile ownership is per character.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Saved item slot, family and two-handed occupancy are compatibility-locked. Duplicate to change them. No ownership is removed.',
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _eligibility(Map<String, dynamic> draft) {
    try {
      final item = ItemSource.decode(draft);
      return 'Equipment eligibility (Core): ${item.eligibleCharacters.map((c) => c.name).join(', ')}';
    } on Object catch (e) {
      return 'Eligibility unavailable: $e';
    }
  }
}

class _CreateItemDialog extends StatefulWidget {
  const _CreateItemDialog({required this.existingIds});
  final Set<String> existingIds;
  @override
  State<_CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<_CreateItemDialog> {
  final _form = GlobalKey<FormState>();
  String _id = '', _en = '', _fr = '';
  ItemCategory _category = ItemCategory.weapon;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create item'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ItemCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in ItemCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.name)),
                ],
                onChanged: (v) => _category = v!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'New stable ID'),
                onChanged: (v) => _id = v,
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[a-z][A-Za-z0-9_]{0,79}$').hasMatch(v) ||
                        reservedItemIds.contains(v) ||
                        widget.existingIds.contains(v)
                    ? 'Use a unique non-reserved identifier.'
                    : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'English name'),
                onChanged: (v) => _en = v,
                validator: (v) =>
                    v == null || v.trim().isEmpty || v.length > 120
                    ? 'Enter a name of 1–120 characters.'
                    : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'French name'),
                onChanged: (v) => _fr = v,
                validator: (v) =>
                    v == null || v.trim().isEmpty || v.length > 120
                    ? 'Enter a name of 1–120 characters.'
                    : null,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, {
              'category': _category.name,
              'newId': _id,
              'name': {'en': _en, 'fr': _fr},
            });
          }
        },
        child: const Text('Create'),
      ),
    ],
  );
}
