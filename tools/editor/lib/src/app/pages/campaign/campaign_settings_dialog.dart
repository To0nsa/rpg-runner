import 'dart:io';

import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../campaign/campaign_map_asset.dart';
import '../../../workspace/editor_workspace.dart';
import '../shared/editor_native_file_picker.dart';
import 'campaign_localized_text_fields.dart';
import 'campaign_journal_fields.dart';

Future<String?> pickCampaignMapFilePath({required String initialDirectory}) =>
    pickEditorFilePath(
      initialDirectory: initialDirectory,
      typeLabel: 'Campaign maps',
      extensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );

/// Holds an unaccepted settings form; only Apply returns a plugin command payload.
class CampaignSettingsDialog extends StatefulWidget {
  const CampaignSettingsDialog({
    super.key,
    required this.catalog,
    required this.workspace,
    this.filePicker = pickCampaignMapFilePath,
  });
  final CampaignCatalogSource catalog;
  final EditorWorkspace workspace;
  final EditorNativeFilePicker filePicker;

  @override
  State<CampaignSettingsDialog> createState() => _CampaignSettingsDialogState();
}

class _CampaignSettingsDialogState extends State<CampaignSettingsDialog> {
  final _form = GlobalKey<FormState>();
  final _localizedFields = GlobalKey<CampaignLocalizedTextFieldsState>();
  final _journal = GlobalKey<CampaignJournalFieldsState>();
  late final _title = Map<String, String>.of(widget.catalog.title);
  late CampaignMapSource _map = widget.catalog.map;
  bool _busy = false;
  String? _error;

  Future<void> _chooseMap() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final directory = Directory(
        widget.workspace.resolve('assets/images/maps'),
      );
      final selected = await widget.filePicker(
        initialDirectory: directory.existsSync()
            ? directory.path
            : widget.workspace.rootPath,
      );
      if (selected == null || !mounted) return;
      final map = await readCampaignMapAsset(widget.workspace, selected);
      if (mounted) setState(() => _map = map);
    } on Object catch (error) {
      if (mounted) setState(() => _error = 'Could not select map: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Campaign settings'),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CampaignLocalizedTextFields(
                key: _localizedFields,
                title: _title,
                titleLabel: 'Campaign name',
              ),
              const SizedBox(height: 24),
              Text(
                'Campaign map',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Image.file(
                File(widget.workspace.resolve(_map.assetPath)),
                height: 180,
                fit: BoxFit.contain,
                cacheWidth: 700,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 80,
                  child: Center(child: Text('Map preview unavailable.')),
                ),
              ),
              const SizedBox(height: 12),
              Text(_map.assetPath),
              const SizedBox(height: 4),
              Text('${_map.width} × ${_map.height}'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const ValueKey('campaign_choose_map'),
                onPressed: _busy ? null : _chooseMap,
                icon: const Icon(Icons.folder_open),
                label: Text(_busy ? 'Opening map…' : 'Choose map…'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose an image in assets/images/maps. Chapter positions stay unchanged; review them after changing maps.',
              ),
              const SizedBox(height: 24),
              CampaignJournalFields(
                key: _journal,
                label: 'Campaign opening',
                entry: widget.catalog.journal,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
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
        onPressed: _busy
            ? null
            : () {
                if (!_form.currentState!.validate()) {
                  _localizedFields.currentState!.revealFirstError();
                  _journal.currentState!.revealFirstError();
                  return;
                }
                _form.currentState!.save();
                Navigator.pop(context, <String, Object?>{
                  'title': _title,
                  'map': _map.toJson(),
                  if (_journal.currentState!.value case final entry?)
                    'journal': entry.toJson(),
                });
              },
        child: const Text('Apply'),
      ),
    ],
  );
}
