import 'package:flutter/material.dart';
import 'package:tool_ui/tool_ui.dart';

/// Keeps both translations in the enclosing form while showing one language.
/// The caller owns the draft maps; FormState.save writes trimmed values.
/// Optional change callbacks retain drafts when an enclosing section is toggled.
class CampaignLocalizedTextFields extends StatefulWidget {
  const CampaignLocalizedTextFields({
    super.key,
    required this.title,
    required this.titleLabel,
    this.description,
    this.descriptionLabel,
    this.onTitleChanged,
    this.titleMaxLength = 120,
    this.titleMaxLines = 1,
    this.descriptionMaxLength = 2000,
    this.descriptionMaxLines = 3,
    this.onDescriptionChanged,
  }) : assert((description == null) == (descriptionLabel == null));

  final Map<String, String> title;
  final Map<String, String>? description;
  final String titleLabel;
  final int titleMaxLength, titleMaxLines;
  final int descriptionMaxLength, descriptionMaxLines;
  final String? descriptionLabel;
  final void Function(String language, String value)? onTitleChanged;
  final void Function(String language, String value)? onDescriptionChanged;

  @override
  State<CampaignLocalizedTextFields> createState() =>
      CampaignLocalizedTextFieldsState();
}

class CampaignLocalizedTextFieldsState
    extends State<CampaignLocalizedTextFields>
    with SingleTickerProviderStateMixin {
  static const _languages = ['en', 'fr'];
  final _fields = [
    for (final _ in _languages)
      [
        GlobalKey<FormFieldState<String>>(),
        GlobalKey<FormFieldState<String>>(),
      ],
  ];
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _languages.length, vsync: this);
  }

  /// Call after the enclosing form fails validation to reveal hidden errors.
  void revealFirstError() {
    for (var index = 0; index < _fields.length; index++) {
      if (_fields[index].any((key) => key.currentState?.hasError ?? false)) {
        _tabs.animateTo(index);
        return;
      }
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolLanguageTabs(
    controller: _tabs,
    english: _fieldsFor(0),
    french: _fieldsFor(1),
  );

  Widget _fieldsFor(int index) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextFormField(
        key: _fields[index][0],
        initialValue: widget.title[_languages[index]],
        decoration: InputDecoration(
          labelText: '${widget.titleLabel} (${_languages[index]})',
        ),
        maxLength: widget.titleMaxLength,
        maxLines: widget.titleMaxLines,
        validator: (value) => _required(value, widget.titleMaxLength),
        onChanged: (value) =>
            widget.onTitleChanged?.call(_languages[index], value),
        onSaved: (value) => widget.title[_languages[index]] = value!.trim(),
      ),
      if (widget.description != null)
        TextFormField(
          key: _fields[index][1],
          initialValue: widget.description![_languages[index]],
          decoration: InputDecoration(
            labelText: '${widget.descriptionLabel} (${_languages[index]})',
          ),
          maxLines: widget.descriptionMaxLines,
          maxLength: widget.descriptionMaxLength,
          validator: (value) => _required(value, widget.descriptionMaxLength),
          onChanged: (value) =>
              widget.onDescriptionChanged?.call(_languages[index], value),
          onSaved: (value) =>
              widget.description![_languages[index]] = value!.trim(),
        ),
    ],
  );
}

String? _required(String? value, int maximum) =>
    value == null || value.trim().isEmpty
    ? 'Required.'
    : value.length > maximum
    ? 'Use at most $maximum characters.'
    : null;
