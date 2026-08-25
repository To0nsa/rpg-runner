import 'package:flutter/material.dart';

import '../../../../prefabs/domain/prefab_domain_models.dart';
import '../../../../prefabs/models/models.dart';
import 'prefab_v3_owner_form.dart';

/// Opens the retained create-only shell around the reusable owner form.
///
/// Existing Prefab metadata is edited inline in the owner list; this dialog is
/// retained only until the planned inline creation section replaces it.
Future<PrefabV3OwnerFormValue?> showPrefabV3CreateDialog(
  BuildContext context, {
  required PrefabV3Document document,
}) => showDialog<PrefabV3OwnerFormValue>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Create prefab owner'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: PrefabV3OwnerForm(
          document: document,
          autofocusId: true,
          submitLabel: 'Create',
          submitKey: const ValueKey<String>('prefab_v3_owner_dialog_apply'),
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: (value) {
            Navigator.of(context).pop(value);
            return true;
          },
        ),
      ),
    ),
  ),
);

/// Opens the stable-key-preserving human-ID rename form.
///
/// This lifecycle form remains temporarily retained until contextual inline
/// rename lands in the next migration phase.
Future<String?> showPrefabV3RenameDialog(
  BuildContext context, {
  required PrefabV3Document document,
  required PrefabV3Def prefab,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _PrefabV3RenameDialog(document: document, prefab: prefab),
);

final class _PrefabV3RenameDialog extends StatefulWidget {
  const _PrefabV3RenameDialog({required this.document, required this.prefab});

  final PrefabV3Document document;
  final PrefabV3Def prefab;

  @override
  State<_PrefabV3RenameDialog> createState() => _PrefabV3RenameDialogState();
}

final class _PrefabV3RenameDialogState extends State<_PrefabV3RenameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.prefab.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rename prefab owner'),
    content: SizedBox(
      width: 420,
      child: TextField(
        key: const ValueKey<String>('prefab_v3_rename_id_field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Human ID',
          errorText: _error,
          helperText: 'The stable prefab key is preserved.',
        ),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const ValueKey<String>('prefab_v3_rename_apply'),
        onPressed: _submit,
        child: const Text('Rename'),
      ),
    ],
  );

  void _submit() {
    final value = _validOwnerId(
      _controller.text,
      document: widget.document,
      exceptPrefabKey: widget.prefab.prefabKey,
    );
    if (value != null) {
      Navigator.of(context).pop(value);
    } else {
      setState(() => _error = 'Enter a unique trimmed ID.');
    }
  }
}

String? _validOwnerId(
  String raw, {
  required PrefabV3Document document,
  String? exceptPrefabKey,
}) {
  final id = raw.trim();
  if (id.isEmpty || id != raw) return null;
  final folded = id.toLowerCase();
  if (document.data.prefabs.any(
    (prefab) =>
        prefab.prefabKey != exceptPrefabKey &&
        prefab.id.toLowerCase() == folded,
  )) {
    return null;
  }
  return id;
}
