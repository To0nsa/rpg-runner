import 'package:flame/cache.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';

import '../../core/players/player_character_definition.dart';
import '../../core/players/player_character_registry.dart';
import '../../core/snapshots/enums.dart';
import '../../game/components/player/player_animations.dart';

/// Lightweight UI preview for a character's idle animation.
///
/// Caches animation loads per character to avoid asset churn in menus.
class PlayerIdlePreview extends StatelessWidget {
  const PlayerIdlePreview({
    super.key,
    required this.characterId,
    this.size = 88,
  });

  final PlayerCharacterId characterId;
  final double size;

  static final Images _images = Images();
  static final Paint _paint = Paint()..filterQuality = FilterQuality.none;
  static final Map<PlayerCharacterId, Future<_IdleAnimBundle>> _cache =
      <PlayerCharacterId, Future<_IdleAnimBundle>>{};

  static Future<_IdleAnimBundle> _loadIdleBundle(
    PlayerCharacterId characterId,
  ) async {
    final def =
        PlayerCharacterRegistry.byId[characterId] ??
        PlayerCharacterRegistry.defaultCharacter;
    final animSet = await loadPlayerAnimations(
      _images,
      renderAnim: def.renderAnim,
    );
    final idle = animSet.animations[AnimKey.idle];
    if (idle == null) {
      throw StateError('Missing idle animation for $characterId');
    }
    return _IdleAnimBundle(animation: idle, anchor: animSet.anchor);
  }

  @override
  Widget build(BuildContext context) {
    final future = _cache.putIfAbsent(
      characterId,
      () => _loadIdleBundle(characterId),
    );

    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<_IdleAnimBundle>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildPlaceholder();
          }
          final data = snapshot.data;
          if (data == null || snapshot.hasError) {
            return _buildPlaceholder();
          }

          return RepaintBoundary(
            child: Transform.scale(
              scaleX: -1,
              alignment: Alignment.center,
              child: SpriteAnimationWidget(
                animation: data.animation,
                animationTicker: data.animation.createTicker(),
                anchor: data.anchor,
                paint: _paint,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: const Icon(Icons.person, color: Colors.white24, size: 20),
    );
  }
}

class _IdleAnimBundle {
  const _IdleAnimBundle({required this.animation, required this.anchor});

  final SpriteAnimation animation;
  final Anchor anchor;
}
