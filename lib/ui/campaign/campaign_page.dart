import 'package:flutter/material.dart';

import '../app/ui_routes.dart';
import '../components/menu_scaffold.dart';
import '../l10n/app_localization.dart';
import '../theme/ui_tokens.dart';
import 'campaign_chapter_dialog.dart';
import 'campaign_map.dart';

/// Keeps the regional map mounted while chapter details open in a modal.
class CampaignPage extends StatelessWidget {
  const CampaignPage({super.key});

  @override
  Widget build(BuildContext context) => MenuScaffold(
    title: context.l10n.campaignHeading,
    overlayAppBar: true,
    background: ColoredBox(color: context.ui.colors.background),
    child: CampaignRegionalMap(
      onChapterPressed: (chapter) => showDialog<void>(
        context: context,
        routeSettings: RouteSettings(
          name: '${UiRoutes.campaign}/chapter/${chapter.id}',
        ),
        builder: (_) => CampaignChapterDialog(chapter: chapter),
      ),
    ),
  );
}
