import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:runner_core/players/player_character_definition.dart';

import '../assets/ui_asset_lifecycle.dart';

/// Lightweight UI preview for a character's idle animation.
///
/// Caches animation loads per character to avoid asset churn in menus.
class PlayerIdlePreview extends StatefulWidget {
  const PlayerIdlePreview({
    super.key,
    required this.characterId,
    this.size = 88,
  });

  final PlayerCharacterId characterId;
  final double size;

  @override
  State<PlayerIdlePreview> createState() => _PlayerIdlePreviewState();
}

class _PlayerIdlePreviewState extends State<PlayerIdlePreview> {
  static final Paint _paint = Paint()..filterQuality = FilterQuality.none;
  UiAssetLifecycle? _lifecycle;
  PlayerCharacterId? _characterId;
  Future<IdleAnimBundle>? _idleFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateFuture(Provider.of<UiAssetLifecycle>(context));
  }

  @override
  void didUpdateWidget(PlayerIdlePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterId != widget.characterId) {
      _updateFuture(_lifecycle!);
    }
  }

  void _updateFuture(UiAssetLifecycle lifecycle) {
    if (identical(_lifecycle, lifecycle) &&
        _idleFuture != null &&
        _characterId == widget.characterId) {
      return;
    }
    _lifecycle = lifecycle;
    _characterId = widget.characterId;
    _idleFuture = lifecycle.getIdle(widget.characterId);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<IdleAnimBundle>(
        future: _idleFuture,
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
