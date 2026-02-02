import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import '../../core/players/player_character_definition.dart';
import '../../core/players/player_character_registry.dart';
import '../../core/snapshots/enums.dart';
import '../../game/components/player/player_animations.dart';
import '../../game/themes/parallax_theme_registry.dart';
import 'asset_scopes.dart';
import 'lru_cache.dart';

class IdleAnimBundle {
  const IdleAnimBundle({
    required this.animation,
    required this.anchor,
  });

  final SpriteAnimation animation;
  final Anchor anchor;
}

class UiAssetLifecycle {
  UiAssetLifecycle({
    int maxHubThemes = 8,
    int maxHubCharacters = 4,
    int maxRunThemes = 0,
    int maxRunCharacters = 0,
  }) : _hubParallaxCache = LruCache<String, List<AssetImage>>(
         maxEntries: maxHubThemes,
         onEvict: _evictParallaxLayers,
       ),
       _runParallaxCache = LruCache<String, List<AssetImage>>(
         maxEntries: maxRunThemes,
         onEvict: _evictParallaxLayers,
       ),
       _hubIdleCache = LruCache<PlayerCharacterId, IdleAnimBundle>(
         maxEntries: maxHubCharacters,
       ),
       _runIdleCache = LruCache<PlayerCharacterId, IdleAnimBundle>(
         maxEntries: maxRunCharacters,
       );

  final Images _idleImages = Images();

  final LruCache<String, List<AssetImage>> _hubParallaxCache;
  final LruCache<String, List<AssetImage>> _runParallaxCache;
  final LruCache<PlayerCharacterId, IdleAnimBundle> _hubIdleCache;
  final LruCache<PlayerCharacterId, IdleAnimBundle> _runIdleCache;

  final Map<PlayerCharacterId, Future<IdleAnimBundle>> _hubIdleInFlight =
      <PlayerCharacterId, Future<IdleAnimBundle>>{};
  final Map<PlayerCharacterId, Future<IdleAnimBundle>> _runIdleInFlight =
      <PlayerCharacterId, Future<IdleAnimBundle>>{};

  final Map<AssetImage, Future<void>> _parallaxPrecacheInFlight =
      <AssetImage, Future<void>>{};

  Future<IdleAnimBundle> getIdle(
    PlayerCharacterId id, {
    AssetScope scope = AssetScope.hub,
  }) {
    final cache = _idleCacheFor(scope);
    final cached = cache.get(id);
    if (cached != null) return Future.value(cached);

    final inFlight = _idleInFlightFor(scope);
    final existing = inFlight[id];
    if (existing != null) return existing;

    final future = _loadIdleBundle(id).then((bundle) {
      cache.put(id, bundle);
      inFlight.remove(id);
      return bundle;
    }).catchError((error, stackTrace) {
      inFlight.remove(id);
      return Future<IdleAnimBundle>.error(error, stackTrace);
    });

    inFlight[id] = future;
    return future;
  }

  Future<List<AssetImage>> getParallaxLayers(
    String? themeId, {
    AssetScope scope = AssetScope.hub,
  }) async {
    final cache = _parallaxCacheFor(scope);
    final key = _cacheKeyForTheme(themeId);
    final cached = cache.get(key);
    if (cached != null) return cached;

    final built = _buildParallaxLayers(themeId);
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
    required String? themeId,
    required PlayerCharacterId characterId,
    required BuildContext context,
  }) async {
    try {
      final layers = await getParallaxLayers(
        themeId,
        scope: AssetScope.hub,
      );
      await Future.wait([
        getIdle(characterId, scope: AssetScope.hub),
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

  void purgeRunCaches() {
    _runParallaxCache.clear();
    _runIdleCache.clear();
    _runIdleInFlight.clear();
  }

  void purgeAll() {
    _hubParallaxCache.clear();
    _runParallaxCache.clear();
    _hubIdleCache.clear();
    _runIdleCache.clear();
    _hubIdleInFlight.clear();
    _runIdleInFlight.clear();
    _parallaxPrecacheInFlight.clear();
    _idleImages.clearCache();
  }

  void dispose() => purgeAll();

  LruCache<String, List<AssetImage>> _parallaxCacheFor(AssetScope scope) {
    return scope == AssetScope.run ? _runParallaxCache : _hubParallaxCache;
  }

  LruCache<PlayerCharacterId, IdleAnimBundle> _idleCacheFor(AssetScope scope) {
    return scope == AssetScope.run ? _runIdleCache : _hubIdleCache;
  }

  Map<PlayerCharacterId, Future<IdleAnimBundle>> _idleInFlightFor(
    AssetScope scope,
  ) {
    return scope == AssetScope.run ? _runIdleInFlight : _hubIdleInFlight;
  }

  Future<IdleAnimBundle> _loadIdleBundle(PlayerCharacterId characterId) async {
    final def =
        PlayerCharacterRegistry.byId[characterId] ??
        PlayerCharacterRegistry.defaultCharacter;
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

  static String _cacheKeyForTheme(String? themeId) {
    return themeId ?? '__null__';
  }

  static List<AssetImage> _buildParallaxLayers(String? themeId) {
    final theme = ParallaxThemeRegistry.forThemeId(themeId);

    AssetImage img(String relToImagesFolder) =>
        AssetImage('assets/images/$relToImagesFolder');

    return <AssetImage>[
      for (final layer in theme.backgroundLayers) img(layer.assetPath),
      img(theme.groundLayerAsset),
      for (final layer in theme.foregroundLayers) img(layer.assetPath),
    ];
  }

  Future<void> _precacheImageOnce(
    AssetImage provider,
    BuildContext context,
  ) {
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
