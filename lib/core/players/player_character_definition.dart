library;

import 'player_tuning.dart';
import 'player_catalog.dart';

enum PlayerCharacterId { eloise }

class PlayerCharacterDefinition {
  const PlayerCharacterDefinition({
    required this.id,
    required this.displayName,
    this.catalog = const PlayerCatalog(),
    this.tuning = const PlayerTuning(),
  });

  final PlayerCharacterId id;
  final String displayName;

  /// Structural player configuration (collider size/offset, physics flags, etc.).
  final PlayerCatalog catalog;

  /// Per-character numeric tuning bundle.
  final PlayerTuning tuning;

  PlayerCharacterDefinition copyWith({
    String? displayName,
    PlayerCatalog? catalog,
    PlayerTuning? tuning,
  }) {
    return PlayerCharacterDefinition(
      id: id,
      displayName: displayName ?? this.displayName,
      catalog: catalog ?? this.catalog,
      tuning: tuning ?? this.tuning,
    );
  }
}

