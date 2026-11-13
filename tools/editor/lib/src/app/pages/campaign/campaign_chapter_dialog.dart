import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../workspace/editor_workspace.dart';
import 'campaign_chapter_map_position.dart';
import 'campaign_localized_text_fields.dart';
import 'campaign_journal_fields.dart';

/// Edits chapter metadata only. Identity allocation, missions and persistence
/// remain with the campaign plugin; Cancel returns no accepted changes.
class CampaignChapterDialog extends StatefulWidget {
  const CampaignChapterDialog({
    super.key,
    this.chapter,
    required this.map,
    required this.workspace,
    this.chapters = const [],
    this.campaignTitle = 'Campaign',
  });
  final CampaignChapterSource? chapter;
  final CampaignMapSource map;
  final EditorWorkspace workspace;
  final List<CampaignChapterSource> chapters;
  final String campaignTitle;

  @override
  State<CampaignChapterDialog> createState() => _CampaignChapterDialogState();
}

class _CampaignChapterDialogState extends State<CampaignChapterDialog> {
  final _form = GlobalKey<FormState>();
  final _localizedFields = GlobalKey<CampaignLocalizedTextFieldsState>();
  final _journal = GlobalKey<CampaignJournalFieldsState>();
  late String _previewTitle = widget.chapter?.title['en'] ?? '';
  late final _title = Map<String, String>.of(
    widget.chapter?.title ?? const {'en': '', 'fr': ''},
  );
  late final _description = Map<String, String>.of(
    widget.chapter?.description ??
        const {'en': 'Describe this chapter.', 'fr': 'Décris ce chapitre.'},
  );
  late final _position = {
    'mapX': widget.chapter?.mapX ?? 0.5,
    'mapY': widget.chapter?.mapY ?? 0.5,
  };
  late final _coordinates = {
    for (final axis in ['mapX', 'mapY'])
      axis: TextEditingController(text: '${_position[axis]}'),
  };

  void _placeMarker(Offset position) {
    setState(() {
      _position['mapX'] = position.dx;
      _position['mapY'] = position.dy;
      for (final axis in _coordinates.keys) {
        _coordinates[axis]!.text = _position[axis]!.toStringAsFixed(4);
        _position[axis] = double.parse(_coordinates[axis]!.text);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _coordinates.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.chapter == null ? 'Create chapter' : 'Chapter settings'),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.chapter == null)
                const Text(
                  'Starts with one empty draft mission using the current region '
                  'and background. Configure it in Mission settings.',
                ),
              CampaignLocalizedTextFields(
                key: _localizedFields,
                title: _title,
                description: _description,
                titleLabel: 'Chapter title',
                descriptionLabel: 'Chapter description',
                onTitleChanged: (language, value) {
                  if (language == 'en') setState(() => _previewTitle = value);
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Chapter marker position',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Map X is the horizontal position (0 = left, 1 = right). '
                'Map Y is the vertical position (0 = top, 1 = bottom).',
              ),
              const SizedBox(height: 12),
              CampaignChapterMapPosition(
                map: widget.map,
                workspace: widget.workspace,
                title: _previewTitle,
                campaignTitle: widget.campaignTitle,
                chapterId: widget.chapter?.id,
                chapters: widget.chapters,
                position: Offset(_position['mapX']!, _position['mapY']!),
                onChanged: _placeMarker,
              ),
              const SizedBox(height: 12),
              for (final axis in ['mapX', 'mapY'])
                TextFormField(
                  key: ValueKey(axis),
                  controller: _coordinates[axis],
                  decoration: InputDecoration(
                    labelText: axis == 'mapX'
                        ? 'Map X (left 0 → right 1)'
                        : 'Map Y (top 0 → bottom 1)',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null || !n.isFinite || n < 0 || n > 1
                        ? 'Enter a position from 0 to 1.'
                        : null;
                  },
                  onChanged: (value) {
                    final n = double.tryParse(value);
                    if (n != null && n.isFinite && n >= 0 && n <= 1) {
                      setState(() => _position[axis] = n);
                    }
                  },
                  onSaved: (v) => _position[axis] = double.parse(v!),
                ),
              const SizedBox(height: 24),
              CampaignJournalFields(
                key: _journal,
                label: 'Chapter introduction',
                entry: widget.chapter?.journal,
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
          if (!_form.currentState!.validate()) {
            _localizedFields.currentState!.revealFirstError();
            _journal.currentState!.revealFirstError();
            return;
          }
          _form.currentState!.save();
          Navigator.pop(context, <String, Object?>{
            'title': _title,
            'description': _description,
            ..._position,
            if (_journal.currentState!.value case final entry?)
              'journal': entry.toJson(),
          });
        },
        child: Text(widget.chapter == null ? 'Create' : 'Apply'),
      ),
    ],
  );
}
