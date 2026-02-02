import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/players/player_character_definition.dart';
import '../assets/ui_asset_lifecycle.dart';

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

  static final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  Widget build(BuildContext context) {
    final lifecycle = context.read<UiAssetLifecycle>();
    final future = lifecycle.getIdle(characterId);

    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<IdleAnimBundle>(
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
