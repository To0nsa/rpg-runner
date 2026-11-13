import 'package:flutter/material.dart';

/// Confirms a named destructive edit. Callers still own stale-state checks and
/// command dispatch; this dialog never writes repository content.
Future<bool> confirmEditorDelete(
  BuildContext context, {
  required String subject,
  required String name,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ConfirmDeleteDialog(subject: subject, name: name, message: message),
    ) ??
    false;

class _ConfirmDeleteDialog extends StatefulWidget {
  const _ConfirmDeleteDialog({
    required this.subject,
    required this.name,
    required this.message,
  });
  final String subject, name, message;

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  String _confirmation = '';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Delete ${widget.subject}?'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          SelectableText(
            widget.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Type the exact name to confirm',
            ),
            onChanged: (value) => setState(() => _confirmation = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _confirmation == widget.name
            ? () => Navigator.pop(context, true)
            : null,
        child: Text('Delete ${widget.subject}'),
      ),
    ],
  );
}
