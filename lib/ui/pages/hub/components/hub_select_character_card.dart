import 'package:flutter/material.dart';

import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'hub_select_card_body.dart';
import 'hub_select_card_frame.dart';
import '../../../components/player_idle_preview.dart';
import '../../../theme/ui_hub_theme.dart';

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
    final hub = context.hub;
    final def = PlayerCharacterRegistry.resolve(characterId);

    return HubSelectCardFrame(
      onTap: onChange,
      frameColor: Colors.transparent,
      background: const ColoredBox(color: Colors.transparent),
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
