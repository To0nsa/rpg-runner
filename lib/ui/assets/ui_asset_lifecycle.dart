import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

import 'package:runner_core/contracts/render_anim_set_definition.dart';
import 'package:runner_core/enemies/enemy_catalog.dart';
import 'package:runner_core/enemies/enemy_id.dart';
import 'package:runner_core/levels/level_id.dart';
import 'package:runner_core/levels/level_registry.dart';
import 'package:runner_core/players/player_character_definition.dart';
import 'package:runner_core/players/player_character_registry.dart';
import 'package:runner_core/projectiles/projectile_id.dart';
import 'package:runner_core/projectiles/projectile_render_catalog.dart';
import 'package:runner_core/pickups/pickup_render_catalog.dart';
import 'package:runner_core/spell_impacts/spell_impact_id.dart';
import 'package:runner_core/spell_impacts/spell_impact_render_catalog.dart';
import 'package:runner_core/snapshots/entity_render_snapshot.dart';
import 'package:runner_core/snapshots/enums.dart';
import '../../game/components/player/player_animations.dart';
import '../../game/themes/parallax_theme_registry.dart';
import 'asset_scopes.dart';
import 'lru_cache.dart';

class IdleAnimBundle {
  const IdleAnimBundle({required this.animation, required this.anchor});

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
  final Map<String, Future<void>> _runBootstrapWarmInFlight =
      <String, Future<void>>{};

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
      final layers = await getParallaxLayers(themeId, scope: AssetScope.hub);
      if (!context.mounted) return;
      await Future.wait([
        getIdle(characterId, scope: AssetScope.hub),
        precacheParallaxLayers(layers, context),
      ]);
      trimHubCaches();
    } catch (_) {
      // Best-effort warmup.
    }
  }

  /// Best-effort warmup for run-start assets while the bootstrap route is
  /// visible.
  ///
  /// This keeps run-start asset orchestration in a single module and shifts
  /// decode pressure before entering the run route.
  Future<void> warmRunStartAssets({
    required LevelId levelId,
    required PlayerCharacterId characterId,
    required BuildContext context,
  }) {
    final key = '${levelId.name}:${characterId.name}';
    final existing = _runBootstrapWarmInFlight[key];
    if (existing != null) return existing;

    final future =
        _warmRunStartAssetsImpl(
          levelId: levelId,
          characterId: characterId,
          context: context,
        ).whenComplete(() {
          _runBootstrapWarmInFlight.remove(key);
        });

    _runBootstrapWarmInFlight[key] = future;
    return future;
  }

  void trimHubCaches() {
    _hubParallaxCache.trim();
    _hubIdleCache.trim();
  }

  void purgeRunCaches() {
    _runParallaxCache.clear();
    _runIdleCache.clear();
    _runIdleInFlight.clear();
    _runBootstrapWarmInFlight.clear();
  }

  void purgeAll() {
    _hubParallaxCache.clear();
    _runParallaxCache.clear();
    _hubIdleCache.clear();
    _runIdleCache.clear();
    _hubIdleInFlight.clear();
    _runIdleInFlight.clear();
    _runBootstrapWarmInFlight.clear();
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

  static String _cacheKeyForTheme(String? themeId) {
    return themeId ?? '__null__';
  }

  static List<AssetImage> _buildParallaxLayers(String? themeId) {
    final theme = ParallaxThemeRegistry.forThemeId(themeId);

    AssetImage img(String relToImagesFolder) =>
        AssetImage('assets/images/$relToImagesFolder');

    return <AssetImage>[
      for (final layer in theme.backgroundLayers) img(layer.assetPath),
      img(theme.groundMaterialAssetPath),
      for (final layer in theme.foregroundLayers) img(layer.assetPath),
    ];
  }

  Future<void> _warmRunStartAssetsImpl({
    required LevelId levelId,
    required PlayerCharacterId characterId,
    required BuildContext context,
  }) async {
    try {
      final themeId = LevelRegistry.byId(levelId).themeId;
      final parallaxLayers = await getParallaxLayers(
        themeId,
        scope: AssetScope.run,
      );
      if (!context.mounted) return;

      final relPaths = _collectRunStartImagePaths(characterId: characterId);

      final futures = <Future<void>>[
        getIdle(characterId, scope: AssetScope.run).then((_) {}),
        precacheParallaxLayers(parallaxLayers, context),
      ];
      for (final relPath in relPaths) {
        futures.add(
          _precacheImageOnce(AssetImage('assets/images/$relPath'), context),
        );
      }

      await Future.wait(futures);
    } catch (_) {
      // Best-effort warmup.
    }
  }

  static Set<String> _collectRunStartImagePaths({
    required PlayerCharacterId characterId,
  }) {
    final paths = <String>{};

    void addFromRenderAnim(RenderAnimSetDefinition renderAnim) {
      for (final rawPath in renderAnim.sourcesByKey.values) {
        final path = rawPath.trim();
        if (path.isNotEmpty) {
          paths.add(path);
        }
      }
    }

    addFromRenderAnim(PlayerCharacterRegistry.resolve(characterId).renderAnim);

    const enemyCatalog = EnemyCatalog();
    for (final enemyId in EnemyId.values) {
      addFromRenderAnim(enemyCatalog.get(enemyId).renderAnim);
    }

    const projectileCatalog = ProjectileRenderCatalog();
    for (final projectileId in ProjectileId.values) {
      if (projectileId == ProjectileId.unknown) continue;
      addFromRenderAnim(projectileCatalog.get(projectileId));
    }

    const pickupCatalog = PickupRenderCatalog();
    const pickupVariants = <int>[
      PickupVariant.collectible,
      PickupVariant.restorationHealth,
      PickupVariant.restorationMana,
      PickupVariant.restorationStamina,
    ];
    for (final variant in pickupVariants) {
      addFromRenderAnim(pickupCatalog.get(variant));
    }

    const spellImpactCatalog = SpellImpactRenderCatalog();
    for (final impactId in SpellImpactId.values) {
      if (impactId == SpellImpactId.unknown) continue;
      addFromRenderAnim(spellImpactCatalog.get(impactId));
    }

    return paths;
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
