import 'package:flutter/material.dart';
import 'package:runner_content_pipeline/campaign_journal.dart';

import '../../l10n/app_localization.dart';
import '../../theme/ui_tokens.dart';

/// Renders only the supplied account's settled progress. No local completion
/// event, developer bypass or reading action can reveal an unearned update.
class CampaignJournalView extends StatelessWidget {
  const CampaignJournalView({
    super.key,
    required this.journal,
    required this.isCleared,
  });
  final CampaignJournalContent journal;
  final bool Function(String missionId) isCleared;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final language = Localizations.localeOf(context).languageCode;
    final entries = journal.visibleEntries(isCleared: isCleared);
    return SingleChildScrollView(
      padding: EdgeInsets.all(ui.space.md),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: EdgeInsets.all(ui.space.lg),
          decoration: BoxDecoration(
            color: ui.colors.background,
            border: Border.all(color: ui.colors.outline),
            borderRadius: BorderRadius.circular(ui.radii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entries.isEmpty) Text(context.l10n.journalEmpty),
              for (final item in entries) ...[
                Semantics(
                  header: true,
                  child: Text(
                    item.entry.titleFor(language),
                    key: ValueKey('journal-${item.id}'),
                    style: ui.text.headline,
                  ),
                ),
                SizedBox(height: ui.space.sm),
                Text(
                  item.entry.bodyFor(language),
                  style: ui.text.body.copyWith(fontSize: 18, height: 1.5),
                ),
                SizedBox(height: ui.space.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
