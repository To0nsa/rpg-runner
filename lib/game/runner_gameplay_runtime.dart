import 'package:flame/cache.dart';
import 'package:flutter/foundation.dart';
import 'package:runner_core/game_core.dart';
import 'package:runner_core/snapshots/actor_frame_snapshot.dart';

import 'game_controller.dart';
import 'input/aim_preview.dart';
import 'input/runner_input_router.dart';
import 'replay/ghost_render_frame.dart';
import 'runner_flame_game.dart';
import 'themes/parallax_theme.dart';
import 'themes/terrain_material_registry.dart';

/// The common Core/controller/input/render graph for one local attempt.
///
/// Takes ownership of [core] and a fresh image cache. Sessions select the Core
/// factory and readiness/start policy; this graph starts paused at tick zero.
/// Stop UI bindings before [stop], and unmount the view before [dispose].
final class RunnerGameplayRuntime {
  factory RunnerGameplayRuntime({
    required GameCore core,
    Images Function()? createImages,
    Map<String, ParallaxTheme>? parallaxThemes,
    Map<String, TerrainMaterialSpec>? terrainMaterials,
    ValueListenable<GhostRenderFrame?>? ghostRenderListenable,
    Future<Iterable<ActorFrameSnapshot>>? ghostPreparation,
  }) {
    GameController? controller;
    Images? images;
    final projectile = AimPreviewModel();
    final melee = AimPreviewModel();
    try {
      controller = GameController(core: core, tickHz: core.tickHz)
        ..setPaused(true);
      final input = RunnerInputRouter(controller: controller);
      images = createImages?.call() ?? Images();
      final game = RunnerFlameGame(
        controller: controller,
        input: input,
        playerCharacter: controller.playerCharacter,
        projectileAimPreview: projectile,
        meleeAimPreview: melee,
        imageCache: images,
        parallaxThemes: parallaxThemes,
        terrainMaterials: terrainMaterials,
        ghostRenderListenable: ghostRenderListenable,
        ghostPreparation: ghostPreparation,
      );
      return RunnerGameplayRuntime._(
        controller,
        input,
        game,
        projectile,
        melee,
      );
    } catch (_) {
      controller?.dispose();
      core.stopTerrainPreparation();
      images?.clearCache();
      projectile.dispose();
      melee.dispose();
      rethrow;
    }
  }

  RunnerGameplayRuntime._(
    this.controller,
    this.input,
    this.game,
    this.projectilePreview,
    this.meleePreview,
  );

  final GameController controller;
  final RunnerInputRouter input;
  final RunnerFlameGame game;
  final AimPreviewModel projectilePreview;
  final AimPreviewModel meleePreview;
  bool _stopped = false;
  bool _disposed = false;

  /// Fences loading and ticking immediately, retaining view-readable notifiers.
  void stop() {
    if (_stopped) return;
    _stopped = true;
    input.cancelAll();
    game.cancelPreparation();
    controller.shutdown();
  }

  /// Releases a retired graph after unmount, including never-mounted attempts.
  /// Flame owns mounted cleanup; the fallback only handles an unhosted game.
  void dispose() {
    if (_disposed) return;
    stop();
    game.disposeAfterUnmount();
    _disposed = true;
    controller.dispose();
    projectilePreview.dispose();
    meleePreview.dispose();
  }
}
