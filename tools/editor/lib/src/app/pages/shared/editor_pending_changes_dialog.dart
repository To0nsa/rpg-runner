import 'package:flutter/material.dart';

/// Result of resolving a local draft before navigation or editor replacement.
enum EditorPendingChangesAction { save, discard, cancel }

/// Presents the editor's shared non-dismissible local-draft decision.
///
/// Callers retain ownership of Save and Discard effects. Stable keys are
/// supplied by the domain so existing automation and semantics remain intact.
Future<EditorPendingChangesAction?> showEditorPendingChangesDialog({
  required BuildContext context,
  required Key dialogKey,
  required String title,
  required Widget content,
  required Key cancelKey,
  required Key discardKey,
  required Key saveKey,
}) => showDialog<EditorPendingChangesAction>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    key: dialogKey,
    title: Text(title),
    content: content,
    actions: <Widget>[
      TextButton(
        key: cancelKey,
        onPressed: () =>
            Navigator.of(context).pop(EditorPendingChangesAction.cancel),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: discardKey,
        onPressed: () =>
            Navigator.of(context).pop(EditorPendingChangesAction.discard),
        child: const Text('Discard'),
      ),
      FilledButton(
        key: saveKey,
        onPressed: () =>
            Navigator.of(context).pop(EditorPendingChangesAction.save),
        child: const Text('Save'),
      ),
    ],
  ),
);
