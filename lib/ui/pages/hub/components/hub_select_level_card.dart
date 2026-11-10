import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';

import 'package:runner_core/levels/level_id.dart';

import '../../../levels/level_id_ui.dart';
import 'hub_select_card_body.dart';
import 'hub_select_card_frame.dart';
import '../../../components/level_card_artwork.dart';

/// Hub card showing the currently selected level.
class HubSelectedLevelCard extends StatelessWidget {
  const HubSelectedLevelCard({
    super.key,
    required this.levelId,
    required this.runModeLabel,
    required this.onChange,
  });

  final LevelId levelId;
  final String runModeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return HubSelectCardFrame(
      onTap: onChange,
      background: LevelCardArtwork(levelId: levelId),
      child: HubSelectCardBody(
        label: context.l10n.uiLevelSelection,
        title: levelId.localizedName(context.l10n).toUpperCase(),
        subtitle: runModeLabel,
      ),
    );
  }
}
