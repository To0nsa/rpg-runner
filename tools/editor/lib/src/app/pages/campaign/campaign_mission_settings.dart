import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

import '../../../campaign/campaign_domain_plugin.dart';
import 'campaign_localized_text_fields.dart';
import 'campaign_journal_fields.dart';

/// Inline field drafts join the page's Save, Play and navigation transaction.
/// Source changes still go through the Campaign plugin's revision-guarded edit.
class CampaignMissionSettings extends StatefulWidget {
  const CampaignMissionSettings({
    super.key,
    required this.document,
    required this.onApply,
    required this.onDraftChanged,
  });

  final CampaignDocument document;
  final ValueChanged<CampaignMissionSource> onApply;
  final VoidCallback onDraftChanged;

  @override
  State<CampaignMissionSettings> createState() =>
      CampaignMissionSettingsState();
}

class CampaignMissionSettingsState extends State<CampaignMissionSettings> {
  var _form = GlobalKey<FormState>();
  var _localized = GlobalKey<CampaignLocalizedTextFieldsState>();
  var _journal = GlobalKey<CampaignJournalFieldsState>();
  late Map<String, String> _title, _description;
  late String _level, _theme;
  late bool _include, _requiresFirstCoin;
  String? _blessingShrineId;
  bool _dirty = false;
  bool get hasDraft => _dirty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CampaignMissionSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.document.selected;
    final after = widget.document.selected;
    if (!identical(before, after)) _load();
  }

  void _load() {
    final mission = widget.document.selected;
    _form = GlobalKey<FormState>();
    _localized = GlobalKey<CampaignLocalizedTextFieldsState>();
    _journal = GlobalKey<CampaignJournalFieldsState>();
    _title = Map.of(mission.title);
    _description = Map.of(mission.description);
    _level = mission.levelId;
    _theme = mission.visualThemeId;
    _include = mission.includeInBuild;
    _requiresFirstCoin = mission.requiresFirstCoin;
    _blessingShrineId = mission.blessingObjectiveShrineId;
    _dirty = false;
  }

  void _changed() {
    if (_dirty) return;
    setState(() => _dirty = true);
    widget.onDraftChanged();
  }

  void cancel() {
    if (!_dirty) return;
    setState(_load);
    widget.onDraftChanged();
  }

  /// Accepts valid visible fields before page actions; invalid drafts stay put.
  bool save() {
    if (!_dirty) return true;
    if (!_form.currentState!.validate()) {
      _localized.currentState!.revealFirstError();
      _journal.currentState!.revealFirstError();
      return false;
    }
    _form.currentState!.save();
    final data = widget.document.selected.toJson()
      ..addAll({
        'title': _title,
        'description': _description,
        'levelId': _level,
        'visualThemeId': _theme,
        'includeInBuild': _include,
        'requiresFirstCoin': _requiresFirstCoin,
      });
    data.remove('blessingObjectiveShrineId');
    data.remove('journal');
    if (_journal.currentState!.value case final entry?) {
      data['journal'] = entry.toJson();
    }
    if (_blessingShrineId != null) {
      data['blessingObjectiveShrineId'] = _blessingShrineId;
    }
    setState(() => _dirty = false);
    widget.onApply(CampaignMissionSource.decode(data));
    widget.onDraftChanged();
    return true;
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    onChanged: _changed,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampaignLocalizedTextFields(
          key: _localized,
          title: _title,
          description: _description,
          titleLabel: 'Title',
          descriptionLabel: 'Assignment',
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _level,
          decoration: const InputDecoration(labelText: 'Region level'),
          items: [
            for (final level in widget.document.chunks.levels)
              DropdownMenuItem(
                value: level.levelId,
                child: Text(
                  level.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => _level = value!,
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _theme,
          decoration: const InputDecoration(labelText: 'Background theme'),
          items: [
            for (final theme in widget.document.chunks.parallaxThemes)
              DropdownMenuItem(
                value: theme.parallaxThemeId,
                child: Text(
                  theme.parallaxThemeId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => _theme = value!,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Collect a coin before exiting'),
          subtitle: const Text(
            'Adds a required mission objective. Place at least one gold coin in Markers.',
          ),
          value: _requiresFirstCoin,
          onChanged: (value) {
            setState(() => _requiresFirstCoin = value);
            _changed();
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: _blessingShrineId ?? '',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Receive a blessing before exiting',
            helperText: 'Choose the required shrine marker, or None.',
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('None')),
            for (final shrine
                in widget.document.selected.placements
                    .whereType<CampaignShrineSource>())
              DropdownMenuItem(value: shrine.id, child: Text(shrine.id)),
          ],
          validator: (id) =>
              widget.document.selected.tutorialSequences
                  .whereType<CampaignBlessingTutorial>()
                  .any((lesson) => lesson.shrineId != id)
              ? 'Change or remove the blessing introduction first.'
              : null,
          onChanged: (id) => _blessingShrineId = id == '' ? null : id,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include in game Build'),
          subtitle: const Text(
            'Incomplete drafts can be saved. Included missions must pass Build validation.',
          ),
          value: _include,
          onChanged: (value) {
            setState(() => _include = value);
            _changed();
          },
        ),
        const SizedBox(height: 24),
        CampaignJournalFields(
          key: _journal,
          label: 'Mission completion update',
          entry: widget.document.selected.journal,
          onChanged: _changed,
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _dirty ? save : null,
              child: const Text('Apply'),
            ),
            TextButton(
              onPressed: _dirty ? cancel : null,
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    ),
  );
}
