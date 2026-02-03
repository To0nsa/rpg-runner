import 'package:flutter/material.dart';

import '../../../../core/players/player_character_definition.dart';
import '../../../../core/players/player_character_registry.dart';
import 'hub_select_card_body.dart';
import 'hub_select_card_frame.dart';
import '../../../components/player_idle_preview.dart';
import '../../../theme/ui_hub_theme.dart';
import '../../../theme/ui_tokens.dart';

/// Hub card showing the currently selected character and build name.
class HubSelectCharacterCard extends StatelessWidget {
  const HubSelectCharacterCard({
    super.key,
    required this.characterId,
    required this.buildName,
    required this.onChange,
  });

  final PlayerCharacterId characterId;
  final String buildName;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final ui = context.ui;
    final hub = context.hub;
    final def =
        PlayerCharacterRegistry.byId[characterId] ??
        PlayerCharacterRegistry.defaultCharacter;

    return HubSelectCardFrame(
      onTap: onChange,
      background: DecoratedBox(
        decoration: BoxDecoration(color: ui.colors.cardBackground),
      ),
      child: HubSelectCardBody(
        label: 'CHARACTER SELECTION',
        title: def.displayName,
        subtitle: buildName,
        trailing: PlayerIdlePreview(
          characterId: characterId,
          size: hub.characterPreviewSize,
        ),
      ),
    );
  }
}
