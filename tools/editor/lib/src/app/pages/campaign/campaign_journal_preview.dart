import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/runner_content_pipeline.dart';

/// Uses the same ordered Journal projection as Library with an explicit,
/// read-only checkpoint. Draft content is visible only in this authoring view.
class CampaignJournalPreview extends StatefulWidget {
  const CampaignJournalPreview({
    super.key,
    required this.catalog,
    required this.missionId,
  });
  final CampaignCatalogSource catalog;
  final String missionId;

  @override
  State<CampaignJournalPreview> createState() => _CampaignJournalPreviewState();
}

class _CampaignJournalPreviewState extends State<CampaignJournalPreview> {
  late String _checkpoint = widget.missionId;

  @override
  Widget build(BuildContext context) {
    final entries = widget.catalog.journalContent.previewAfter(
      _checkpoint.isEmpty ? null : _checkpoint,
    );
    return AlertDialog(
      title: const Text('Journal preview'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('journal_preview_checkpoint'),
              initialValue: _checkpoint,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Read after'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Opening only')),
                for (final chapter in widget.catalog.chapters)
                  for (final mission in chapter.missions)
                    DropdownMenuItem(
                      value: mission.id,
                      child: Text(
                        '${chapter.title['en']} · ${mission.title['en']}'
                        '${mission.includeInBuild ? '' : ' (draft)'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _checkpoint = value!),
            ),
            const SizedBox(height: 12),
            const Text(
              'Includes draft missions through this point. Player progress is unchanged.',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'English'),
                        Tab(text: 'Français'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _reading(context, entries, 'en'),
                          _reading(context, entries, 'fr'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _reading(
    BuildContext context,
    List<CampaignJournalItem> entries,
    String language,
  ) => SingleChildScrollView(
    key: PageStorageKey('journal_preview_$language'),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty) const Text('No Journal entries at this point.'),
        for (final item in entries) ...[
          SelectableText(
            item.entry.titleFor(language),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SelectableText(item.entry.bodyFor(language)),
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}
