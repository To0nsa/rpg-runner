import 'package:game_presentation/character_text.dart';
import 'package:game_presentation/game_localization.dart';
import 'package:rpg_runner/ui/l10n/app_localization.dart';
import 'package:flutter/material.dart';

import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';

import 'hub_select_card_body.dart';
import 'hub_card_action.dart';
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
      footer: HubCardAction(
        label: context.l10n.hubChangeBuild,
        variant: HubCardActionVariant.change,
        onPressed: onChange,
      ),
      background: ColoredBox(color: hub.surface),
      child: HubSelectCardBody(
        label: context.l10n.uiCharacter,
        title: characterDisplayName(def.id, strings: context.gameL10n),
        subtitle: buildName,
        characterPreview: ExcludeSemantics(
          child: PlayerIdlePreview(
            characterId: characterId,
            size: hub.characterPreviewSize,
          ),
        ),
      ),
    );
  }
}
