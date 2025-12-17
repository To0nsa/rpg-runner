import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_controller.dart';

/// UI-layer providers used to access the running game instance from Flutter.
///
/// This is part of the embeddable runner API surface (used by
/// `RunnerGameWidget` / overlays).
final gameControllerProvider = Provider<GameController>((ref) {
  throw UnimplementedError(
    'Override gameControllerProvider in RunnerGameWidget.',
  );
});
