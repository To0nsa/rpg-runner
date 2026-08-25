import 'dart:async';

import 'package:flutter/material.dart';

typedef EditorInlineIdValidator = String? Function(String value);
typedef EditorInlineIdSubmit = FutureOr<bool> Function(String value);

/// Small reusable lifecycle form for stable-key-preserving IDs.
///
/// The form owns only the visible human ID. It reports local dirty state and
/// leaves command selection, optimistic snapshots, and persistence to its
/// containing route.
class EditorInlineIdForm extends StatefulWidget {
  const EditorInlineIdForm({
    super.key,
    required this.initialValue,
    required this.fieldKey,
    required this.submitKey,
    required this.submitLabel,
    required this.helperText,
    required this.validator,
    required this.onSubmit,
    required this.onCancel,
    this.cancelKey,
    this.onDirtyChanged,
    this.autofocus = false,
  });

  final String initialValue;
  final Key fieldKey;
  final Key submitKey;
  final Key? cancelKey;
  final String submitLabel;
  final String helperText;
  final EditorInlineIdValidator validator;
  final EditorInlineIdSubmit onSubmit;
  final VoidCallback onCancel;
  final ValueChanged<bool>? onDirtyChanged;
  final bool autofocus;

  @override
  State<EditorInlineIdForm> createState() => EditorInlineIdFormState();
}

/// Submission handle used when guarded navigation requests Save.
class EditorInlineIdFormState extends State<EditorInlineIdForm> {
  late final TextEditingController _controller;
  String? _fieldError;
  String? _submissionError;
  bool _reportedDirty = false;

  bool get isDirty => _controller.text != widget.initialValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  Future<bool> submit() async {
    final value = _controller.text;
    final error = widget.validator(value);
    if (error != null) {
      setState(() => _fieldError = error);
      return false;
    }
    final accepted = await widget.onSubmit(value);
    if (!accepted && mounted) {
      setState(() {
        _submissionError =
            'The source changed or this action was rejected. Review the '
            'current diagnostics and retry without closing the form.';
      });
    }
    return accepted;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: widget.autofocus,
        decoration: InputDecoration(
          labelText: 'Human ID',
          helperText: widget.helperText,
          errorText: _fieldError,
        ),
        onSubmitted: (_) => submit(),
      ),
      if (_submissionError != null) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          _submissionError!,
          key: const ValueKey<String>('editor_inline_id_submission_error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          TextButton(
            key: widget.cancelKey,
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: widget.submitKey,
            onPressed: submit,
            child: Text(widget.submitLabel),
          ),
        ],
      ),
    ],
  );

  void _handleChanged() {
    if ((_fieldError != null || _submissionError != null) && mounted) {
      setState(() {
        _fieldError = null;
        _submissionError = null;
      });
    }
    final dirty = isDirty;
    if (dirty == _reportedDirty) return;
    _reportedDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }
}
