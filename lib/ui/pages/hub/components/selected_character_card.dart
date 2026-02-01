import 'package:flutter/material.dart';

import '../../../../core/players/player_character_definition.dart';
import '../../../../core/players/player_character_registry.dart';
import 'hub_selection_card_body.dart';
import 'hub_selection_card_frame.dart';
import '../../../components/player_idle_preview.dart';

/// Hub card showing the currently selected character and build name.
class SelectedCharacterCard extends StatelessWidget {
  const SelectedCharacterCard({
    super.key,
    required this.characterId,
    required this.buildName,
    required this.onChange,
    this.width = HubSelectionCardFrame.defaultWidth,
    this.height = HubSelectionCardFrame.defaultHeight,
  });

  final PlayerCharacterId characterId;
  final String buildName;
  final VoidCallback onChange;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final def =
        PlayerCharacterRegistry.byId[characterId] ??
        PlayerCharacterRegistry.defaultCharacter;

    return HubSelectionCardFrame(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      onTap: onChange,
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C111B), Color(0xFF1A2333)],
          ),
        ),
      ),
      child: HubSelectionCardBody(
        headerText: 'CHARACTER SELECTION',
        title: def.displayName,
        subtitle: buildName,
        trailing: PlayerIdlePreview(characterId: characterId, size: 88),
      ),
    );
  }
}
