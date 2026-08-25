import 'package:flutter/material.dart';

import '../../../../chunks/chunk_v2_file_data.dart';
import '../../../../chunks/chunk_v2_models.dart';

/// Opens the create form accepted by the current lifecycle policy.
///
/// This shell remains temporarily retained until Chunk creation moves into its
/// planned inline section; existing owner metadata is edited inline already.
Future<String?> showChunkV2CreateDialog(
  BuildContext context, {
  required ChunkV2Document document,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ChunkV2IdDialog(
    document: document,
    title: 'Create chunk owner',
    applyLabel: 'Create',
    fieldKey: 'chunk_v2_create_id_field',
    applyKey: 'chunk_v2_create_apply',
    helperText:
        'Creates an empty deprecated owner using the active level\'s locked '
        'dimensions.',
  ),
);

/// Opens the stable-key-preserving human-ID rename form.
///
/// This lifecycle form remains temporarily retained until contextual inline
/// rename lands in the next migration phase.
Future<String?> showChunkV2RenameDialog(
  BuildContext context, {
  required ChunkV2Document document,
  required ChunkV2FileData chunk,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ChunkV2IdDialog(
    document: document,
    chunk: chunk,
    title: 'Rename chunk owner',
    applyLabel: 'Rename',
    fieldKey: 'chunk_v2_rename_id_field',
    applyKey: 'chunk_v2_rename_apply',
    helperText: 'The stable chunk key is preserved.',
  ),
);

final class _ChunkV2IdDialog extends StatefulWidget {
  const _ChunkV2IdDialog({
    required this.document,
    required this.title,
    required this.applyLabel,
    required this.fieldKey,
    required this.applyKey,
    required this.helperText,
    this.chunk,
  });

  final ChunkV2Document document;
  final ChunkV2FileData? chunk;
  final String title;
  final String applyLabel;
  final String fieldKey;
  final String applyKey;
  final String helperText;

  @override
  State<_ChunkV2IdDialog> createState() => _ChunkV2IdDialogState();
}

final class _ChunkV2IdDialogState extends State<_ChunkV2IdDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.chunk?.id ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: TextField(
        key: ValueKey<String>(widget.fieldKey),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Human ID',
          errorText: _error,
          helperText: widget.helperText,
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
        key: ValueKey<String>(widget.applyKey),
        onPressed: _submit,
        child: Text(widget.applyLabel),
      ),
    ],
  );

  void _submit() {
    final value = _validOwnerId(
      _controller.text,
      document: widget.document,
      exceptChunkKey: widget.chunk?.chunkKey,
    );
    if (value != null) {
      Navigator.of(context).pop(value);
      return;
    }
    setState(() {
      _error =
          'Use a unique lowercase ID beginning with a letter; digits and '
          'underscores are allowed.';
    });
  }
}

String? _validOwnerId(
  String raw, {
  required ChunkV2Document document,
  String? exceptChunkKey,
}) {
  final id = raw.trim();
  if (id != raw || !_stableChunkId.hasMatch(id)) return null;
  if (document.chunks.any(
    (chunk) => chunk.chunkKey != exceptChunkKey && chunk.id == id,
  )) {
    return null;
  }
  return id;
}

final RegExp _stableChunkId = RegExp(r'^[a-z][a-z0-9_]*$');
