import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/snapshots/enums.dart';

import '../../game/components/player/player_animations.dart';
import '../../game/themes/parallax_theme_registry.dart';
import 'lru_cache.dart';

class IdleAnimBundle {
  const IdleAnimBundle({required this.animation, required this.anchor});

  final SpriteAnimation animation;
  final Anchor anchor;
}

/// Owns menu previews only. Runtime assets are loaded by run-owned registries.
class UiAssetLifecycle {
  UiAssetLifecycle({int maxHubThemes = 8, int maxHubCharacters = 4})
    : _hubParallaxCache = LruCache<String, List<AssetImage>>(
        maxEntries: maxHubThemes,
        onEvict: _evictParallaxLayers,
      ),
      _hubIdleCache = LruCache<PlayerCharacterId, IdleAnimBundle>(
        maxEntries: maxHubCharacters,
      );

  final Images _idleImages = Images();

  final LruCache<String, List<AssetImage>> _hubParallaxCache;
  final LruCache<PlayerCharacterId, IdleAnimBundle> _hubIdleCache;

  final Map<PlayerCharacterId, Future<IdleAnimBundle>> _hubIdleInFlight =
      <PlayerCharacterId, Future<IdleAnimBundle>>{};

  final Map<AssetImage, Future<void>> _parallaxPrecacheInFlight =
      <AssetImage, Future<void>>{};

  Future<IdleAnimBundle> getIdle(PlayerCharacterId id) {
    final cache = _hubIdleCache;
    final cached = cache.get(id);
    if (cached != null) return Future.value(cached);

    final inFlight = _hubIdleInFlight;
    final existing = inFlight[id];
    if (existing != null) return existing;

    final future = _loadIdleBundle(id)
        .then((bundle) {
          cache.put(id, bundle);
          inFlight.remove(id);
          return bundle;
        })
        .catchError((error, stackTrace) {
          inFlight.remove(id);
          return Future<IdleAnimBundle>.error(error, stackTrace);
        });

    inFlight[id] = future;
    return future;
  }

  Future<List<AssetImage>> getParallaxLayers(String? visualThemeId) async {
    final cache = _hubParallaxCache;
    final key = _cacheKeyForTheme(visualThemeId);
    final cached = cache.get(key);
    if (cached != null) return cached;

    final built = _buildParallaxLayers(visualThemeId);
    cache.put(key, built);
    return built;
  }

  Future<void> precacheParallaxLayers(
    List<AssetImage> layers,
    BuildContext context,
  ) async {
    if (layers.isEmpty) return;
    final futures = <Future<void>>[];
    for (final provider in layers) {
      futures.add(_precacheImageOnce(provider, context));
    }
    await Future.wait(futures);
  }

  Future<void> warmHubSelection({
    required String? visualThemeId,
    required PlayerCharacterId characterId,
    required BuildContext context,
  }) async {
    try {
      final layers = await getParallaxLayers(visualThemeId);
      if (!context.mounted) return;
      await Future.wait([
        getIdle(characterId),
        precacheParallaxLayers(layers, context),
      ]);
      trimHubCaches();
    } catch (_) {
      // Best-effort warmup.
    }
  }

  void trimHubCaches() {
    _hubParallaxCache.trim();
    _hubIdleCache.trim();
  }

  void purgeAll() {
    _hubParallaxCache.clear();
    _hubIdleCache.clear();
    _hubIdleInFlight.clear();
    _parallaxPrecacheInFlight.clear();
    _idleImages.clearCache();
  }

  void dispose() => purgeAll();

  Future<IdleAnimBundle> _loadIdleBundle(PlayerCharacterId characterId) async {
    final def = PlayerCharacterRegistry.resolve(characterId);
    final animSet = await loadPlayerAnimations(
      _idleImages,
      renderAnim: def.renderAnim,
    );
    final idle = animSet.animations[AnimKey.idle];
    if (idle == null) {
      throw StateError('Missing idle animation for $characterId');
    }
    return IdleAnimBundle(animation: idle, anchor: animSet.anchor);
  }

  static String _cacheKeyForTheme(String? visualThemeId) {
    return visualThemeId ?? '__null__';
  }

  static List<AssetImage> _buildParallaxLayers(String? visualThemeId) {
    final theme = ParallaxThemeRegistry.forParallaxThemeId(visualThemeId);

    AssetImage img(String relToImagesFolder) =>
        AssetImage('assets/images/$relToImagesFolder');

    return <AssetImage>[
      for (final layer in theme.backgroundLayers) img(layer.assetPath),
      for (final layer in theme.foregroundLayers) img(layer.assetPath),
    ];
  }

  Future<void> _precacheImageOnce(AssetImage provider, BuildContext context) {
    final existing = _parallaxPrecacheInFlight[provider];
    if (existing != null) return existing;

    final future = precacheImage(provider, context)
        .catchError((_) {})
        .whenComplete(() {
          _parallaxPrecacheInFlight.remove(provider);
        });

    _parallaxPrecacheInFlight[provider] = future;
    return future;
  }

  static void _evictParallaxLayers(List<AssetImage> layers) {
    final cache = PaintingBinding.instance.imageCache;
    for (final provider in layers) {
      cache.evict(provider);
    }
  }
}
