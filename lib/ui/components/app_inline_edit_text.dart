import 'package:flutter/material.dart';

import '../theme/ui_inline_edit_text_theme.dart';
import '../theme/ui_tokens.dart';
import 'app_inline_icon_button.dart';

class AppInlineEditText extends StatefulWidget {
  const AppInlineEditText({
    super.key,
    required this.text,
    required this.displayText,
    required this.hintText,
    required this.onCommit,
    this.enabled = true,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
  });

  final String text;
  final String displayText;
  final String hintText;
  final bool enabled;

  final String? Function(String value)? validator;
  final Future<void> Function(String value) onCommit;

  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;

  @override
  State<AppInlineEditText> createState() => _AppInlineEditTextState();
}

class _AppInlineEditTextState extends State<AppInlineEditText> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(covariant AppInlineEditText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing) return;
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!widget.enabled) return;
    setState(() {
      _editing = true;
      _error = null;
      _controller.text = widget.text;
    });
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    if (_saving) return;
    _focusNode.unfocus();
    setState(() {
      _editing = false;
      _error = null;
      _controller.text = widget.text;
    });
  }

  Future<void> _commit() async {
    if (_saving) return;
    if (!widget.enabled) return;

    final raw = _controller.text.trim();
    final err = widget.validator?.call(raw);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onCommit(raw);
      if (!mounted) return;
      _focusNode.unfocus();
      setState(() {
        _saving = false;
        _editing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final spec = context.inlineEditText.resolveSpec(ui: ui);

    if (!_editing) {
      return Row(
        children: [
          Expanded(
            child: Text(
              widget.displayText,
              style: spec.valueStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppInlineIconButton(
            icon: Icons.edit,
            tooltip: 'Edit',
            variant: spec.editButtonVariant,
            size: spec.editButtonSize,
            onPressed: widget.enabled ? _startEditing : null,
          ),
        ],
      );
    }

    final decoration = spec.fieldDecoration.copyWith(
      hintText: widget.hintText,
      errorText: _error,
    );

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            maxLength: widget.maxLength,
            style: spec.valueStyle,
            decoration: decoration,
            onSubmitted: (_) => _commit(),
          ),
        ),
        AppInlineIconButton(
          icon: Icons.check,
          tooltip: 'Save',
          variant: spec.saveButtonVariant,
          size: spec.actionButtonSize,
          loading: _saving,
          onPressed: _saving ? null : _commit,
        ),
        AppInlineIconButton(
          icon: Icons.close,
          tooltip: 'Cancel',
          variant: spec.cancelButtonVariant,
          size: spec.actionButtonSize,
          onPressed: _saving ? null : _cancelEditing,
        ),
      ],
    );
  }
}
