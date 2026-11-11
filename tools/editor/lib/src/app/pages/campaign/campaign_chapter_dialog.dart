import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

/// Edits chapter metadata only. Identity allocation, missions and persistence
/// remain with the campaign plugin; Cancel returns no accepted changes.
class CampaignChapterDialog extends StatefulWidget {
  const CampaignChapterDialog({super.key, this.chapter});
  final CampaignChapterSource? chapter;

  @override
  State<CampaignChapterDialog> createState() => _CampaignChapterDialogState();
}

class _CampaignChapterDialogState extends State<CampaignChapterDialog> {
  final _form = GlobalKey<FormState>();
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.chapter == null ? 'Create chapter' : 'Chapter settings'),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.chapter == null)
                const Text(
                  'Starts with one empty draft mission using the current region '
                  'and background. Configure it in Mission settings.',
                ),
              for (final lang in ['en', 'fr']) ...[
                TextFormField(
                  initialValue: _title[lang],
                  decoration: InputDecoration(
                    labelText: 'Chapter title ($lang)',
                  ),
                  maxLength: 120,
                  validator: _required,
                  onSaved: (v) => _title[lang] = v!.trim(),
                ),
                TextFormField(
                  initialValue: _description[lang],
                  decoration: InputDecoration(
                    labelText: 'Chapter description ($lang)',
                  ),
                  maxLines: 3,
                  maxLength: 2000,
                  validator: _required,
                  onSaved: (v) => _description[lang] = v!.trim(),
                ),
              ],
              for (final axis in ['mapX', 'mapY'])
                TextFormField(
                  initialValue: '${_position[axis]}',
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
                  onSaved: (v) => _position[axis] = double.parse(v!),
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
          if (!_form.currentState!.validate()) return;
          _form.currentState!.save();
          Navigator.pop(context, <String, Object?>{
            'title': _title,
            'description': _description,
            ..._position,
          });
        },
        child: Text(widget.chapter == null ? 'Create' : 'Apply'),
      ),
    ],
  );
}

String? _required(String? v) =>
    v == null || v.trim().isEmpty ? 'Required.' : null;
