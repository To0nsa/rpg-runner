import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/campaign_journal.dart';

import 'campaign_localized_text_fields.dart';

/// One optional entry participates in its owner's enclosing Form and transaction.
/// Turning it off retains unsaved translations until the owner applies or resets.
class CampaignJournalFields extends StatefulWidget {
  const CampaignJournalFields({
    super.key,
    required this.label,
    required this.entry,
    this.onChanged,
  });
  final String label;
  final CampaignJournalEntry? entry;
  final VoidCallback? onChanged;

  @override
  State<CampaignJournalFields> createState() => CampaignJournalFieldsState();
}

class CampaignJournalFieldsState extends State<CampaignJournalFields> {
  final _fields = GlobalKey<CampaignLocalizedTextFieldsState>();
  late bool _enabled = widget.entry != null;
  late final _title = Map<String, String>.of(
    widget.entry?.title ?? const {'en': '', 'fr': ''},
  );
  late final _body = Map<String, String>.of(
    widget.entry?.body ?? const {'en': '', 'fr': ''},
  );

  /// Read only after the enclosing Form has validated and saved both languages.
  CampaignJournalEntry? get value =>
      _enabled ? CampaignJournalEntry(title: _title, body: _body) : null;

  void revealFirstError() => _fields.currentState?.revealFirstError();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.label),
        subtitle: const Text('Include a Journal entry in English and French.'),
        value: _enabled,
        onChanged: (enabled) {
          setState(() => _enabled = enabled);
          widget.onChanged?.call();
        },
      ),
      if (_enabled)
        CampaignLocalizedTextFields(
          key: _fields,
          title: _title,
          description: _body,
          titleLabel: 'Journal title',
          descriptionLabel: 'Journal text',
          titleMaxLength: CampaignJournalEntry.maxTitleLength,
          descriptionMaxLength: CampaignJournalEntry.maxBodyLength,
          descriptionMaxLines: 8,
          onTitleChanged: (language, value) => _title[language] = value,
          onDescriptionChanged: (language, value) => _body[language] = value,
        ),
    ],
  );
}
