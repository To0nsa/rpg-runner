import 'package:flutter/material.dart';

import '../../core/players/player_character_definition.dart';
import '../../core/players/player_character_registry.dart';
import 'hub_selection_card_frame.dart';
import 'menu_button.dart';
import 'player_idle_preview.dart';

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
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHARACTER SELECTION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 2,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    buildName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: PlayerIdlePreview(characterId: characterId, size: 88),
          ),
        ],
      ),
    );
  }
}
