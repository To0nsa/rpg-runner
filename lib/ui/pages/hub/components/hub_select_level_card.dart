import 'package:flutter/material.dart';

import '../../../../core/levels/level_id.dart';
import '../../../levels/level_id_ui.dart';
import 'hub_select_card_body.dart';
import 'hub_select_card_frame.dart';
import '../../../components/level_parallax_preview.dart';
import '../../../theme/ui_tokens.dart';

/// Hub card showing the currently selected level.
class HubSelectedLevelCard extends StatelessWidget {
  const HubSelectedLevelCard({
    super.key,
    required this.levelId,
    required this.runTypeLabel,
    required this.onChange,
  });

  final LevelId levelId;
  final String runTypeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;

    return HubSelectCardFrame(
      onTap: onChange,
      background: LevelParallaxPreview(
        themeId: levelId.themeId,
        baseColor: ui.colors.cardBackground,
        alignment: Alignment.center,
      ),
      child: HubSelectCardBody(
        label: 'LEVEL SELECTION',
        title: levelId.displayName.toUpperCase(),
        subtitle: runTypeLabel,
      ),
    );
  }
}
