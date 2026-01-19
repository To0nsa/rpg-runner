library;

import '../contracts/render_anim_set_definition.dart';
import '../snapshots/enums.dart';
import 'player_tuning.dart';
import 'player_catalog.dart';

enum PlayerCharacterId { eloise }

class PlayerCharacterDefinition {
  const PlayerCharacterDefinition({
    required this.id,
    required this.displayName,
    required this.renderAnim,
    this.catalog = const PlayerCatalog(),
    this.tuning = const PlayerTuning(),
  });

  final PlayerCharacterId id;
  final String displayName;

  /// Render-only animation metadata (strip paths, frame size, timing).
  ///
  /// Core owns the timing numbers so render strips and deterministic animation
  /// windows can stay in sync, but the renderer remains the only layer that
  /// loads assets.
  final RenderAnimSetDefinition renderAnim;

  /// Structural player configuration (collider size/offset, physics flags, etc.).
  final PlayerCatalog catalog;

  /// Per-character numeric tuning bundle.
  final PlayerTuning tuning;

  PlayerCharacterDefinition copyWith({
    String? displayName,
    RenderAnimSetDefinition? renderAnim,
    PlayerCatalog? catalog,
    PlayerTuning? tuning,
  }) {
    return PlayerCharacterDefinition(
      id: id,
      displayName: displayName ?? this.displayName,
      renderAnim: renderAnim ?? this.renderAnim,
      catalog: catalog ?? this.catalog,
      tuning: tuning ?? this.tuning,
    );
  }

  /// Debug-only validation for authoring-time character definitions.
  ///
  /// This is intended to fail fast during development when a new character is
  /// added with incomplete render strip metadata or invalid collider sizes.
  ///
  /// In release builds, asserts are stripped and this becomes a no-op.
  void assertValid() {
    assert(() {
      if (displayName.trim().isEmpty) {
        throw StateError(
          'PlayerCharacterDefinition($id) has empty displayName',
        );
      }

      // Catalog invariants.
      if (!catalog.colliderWidth.isFinite ||
          !catalog.colliderHeight.isFinite ||
          catalog.colliderWidth <= 0 ||
          catalog.colliderHeight <= 0) {
        throw StateError(
          'PlayerCharacterDefinition($id) has invalid collider size '
          '(width=${catalog.colliderWidth}, height=${catalog.colliderHeight})',
        );
      }
      if (!catalog.colliderOffsetX.isFinite ||
          !catalog.colliderOffsetY.isFinite) {
        throw StateError(
          'PlayerCharacterDefinition($id) has non-finite collider offsets '
          '(x=${catalog.colliderOffsetX}, y=${catalog.colliderOffsetY})',
        );
      }

      // Render anim invariants.
      if (renderAnim.frameWidth <= 0 || renderAnim.frameHeight <= 0) {
        throw StateError(
          'PlayerCharacterDefinition($id) has invalid render frame size '
          '(${renderAnim.frameWidth}x${renderAnim.frameHeight})',
        );
      }
      if (!renderAnim.sourcesByKey.containsKey(AnimKey.idle)) {
        throw StateError(
          'PlayerCharacterDefinition($id) renderAnim.sourcesByKey must include AnimKey.idle',
        );
      }
      if (!renderAnim.frameCountsByKey.containsKey(AnimKey.idle)) {
        throw StateError(
          'PlayerCharacterDefinition($id) renderAnim.frameCountsByKey must include AnimKey.idle',
        );
      }
      if (!renderAnim.stepTimeSecondsByKey.containsKey(AnimKey.idle)) {
        throw StateError(
          'PlayerCharacterDefinition($id) renderAnim.stepTimeSecondsByKey must include AnimKey.idle',
        );
      }

      for (final entry in renderAnim.sourcesByKey.entries) {
        final key = entry.key;
        final path = entry.value;
        if (path.trim().isEmpty) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.sourcesByKey[$key] is empty',
          );
        }

        // Frame counts / step times are allowed to be omitted per-key; render
        // falls back to the `idle` values in that case. If a value is provided
        // for the key, validate it.
        final count = renderAnim.frameCountsByKey[key];
        if (count != null && count <= 0) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.frameCountsByKey[$key] must be > 0 (got $count)',
          );
        }
        final seconds = renderAnim.stepTimeSecondsByKey[key];
        if (seconds != null && (!seconds.isFinite || seconds <= 0)) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.stepTimeSecondsByKey[$key] must be > 0 (got $seconds)',
          );
        }
      }

      for (final entry in renderAnim.frameCountsByKey.entries) {
        final key = entry.key;
        final count = entry.value;
        if (count <= 0) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.frameCountsByKey[$key] must be > 0 (got $count)',
          );
        }
        if (key != AnimKey.idle && !renderAnim.sourcesByKey.containsKey(key)) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.frameCountsByKey[$key] has no matching sourcesByKey entry',
          );
        }
      }

      for (final entry in renderAnim.stepTimeSecondsByKey.entries) {
        final key = entry.key;
        final seconds = entry.value;
        if (!seconds.isFinite || seconds <= 0) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.stepTimeSecondsByKey[$key] must be > 0 (got $seconds)',
          );
        }
        if (key != AnimKey.idle && !renderAnim.sourcesByKey.containsKey(key)) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.stepTimeSecondsByKey[$key] has no matching sourcesByKey entry',
          );
        }
      }

      for (final entry in renderAnim.rowByKey.entries) {
        final key = entry.key;
        final row = entry.value;
        if (row < 0) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.rowByKey[$key] must be >= 0 (got $row)',
          );
        }
        if (!renderAnim.sourcesByKey.containsKey(key)) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.rowByKey[$key] has no matching sourcesByKey entry',
          );
        }
        if (!renderAnim.frameCountsByKey.containsKey(key)) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.rowByKey[$key] has no matching frameCountsByKey entry',
          );
        }
      }

      final anchor = renderAnim.anchorInFramePx;
      if (anchor != null) {
        if (!anchor.x.isFinite || !anchor.y.isFinite) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.anchorInFramePx must be finite (got $anchor)',
          );
        }
        if (anchor.x < 0 ||
            anchor.x > renderAnim.frameWidth ||
            anchor.y < 0 ||
            anchor.y > renderAnim.frameHeight) {
          throw StateError(
            'PlayerCharacterDefinition($id) renderAnim.anchorInFramePx must be within the frame '
            '(0..${renderAnim.frameWidth}, 0..${renderAnim.frameHeight}). Got $anchor',
          );
        }
      }

      // Tuning invariants (only basic sanity checks here).
      if (!tuning.anim.hitAnimSeconds.isFinite ||
          !tuning.anim.castAnimSeconds.isFinite ||
          !tuning.anim.attackAnimSeconds.isFinite ||
          !tuning.anim.deathAnimSeconds.isFinite ||
          !tuning.anim.spawnAnimSeconds.isFinite ||
          !tuning.anim.rangedAnimSeconds.isFinite) {
        throw StateError(
          'PlayerCharacterDefinition($id) has non-finite AnimTuning seconds',
        );
      }

      return true;
    }());
  }
}
