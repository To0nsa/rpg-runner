/// Pickup render registry and loaders (render layer only).
library;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';

import '../../../core/contracts/render_anim_set_definition.dart';
import '../../../core/pickups/pickup_render_catalog.dart';
import '../../../core/snapshots/entity_render_snapshot.dart';
import '../../../core/snapshots/enums.dart';
import '../sprite_anim/deterministic_anim_view_component.dart';
import '../sprite_anim/sprite_anim_set.dart';
import '../sprite_anim/strip_animation_loader.dart';

typedef PickupAnimLoader =
    Future<SpriteAnimSet> Function(
      Images images, {
      required RenderAnimSetDefinition renderAnim,
      required Set<AnimKey> oneShotKeys,
    });

typedef PickupViewFactory =
    DeterministicAnimViewComponent Function(
      SpriteAnimSet animSet,
      Vector2 renderScale,
    );

DeterministicAnimViewComponent _defaultPickupViewFactory(
  SpriteAnimSet animSet,
  Vector2 renderScale,
) {
  return DeterministicAnimViewComponent(
    animSet: animSet,
    renderSize: Vector2(animSet.frameSize.x, animSet.frameSize.y),
    renderScale: renderScale,
    respectFacing: false,
  );
}

class PickupRenderEntry {
  PickupRenderEntry({
    required this.variant,
    required this.renderScale,
    this.oneShotKeys = const <AnimKey>{},
    this.loader = loadAnimSetFromDefinition,
    this.viewFactory = _defaultPickupViewFactory,
  });

  final int variant;
  final Vector2 renderScale;
  final Set<AnimKey> oneShotKeys;
  final PickupAnimLoader loader;
  final PickupViewFactory viewFactory;

  SpriteAnimSet? _animSet;

  bool get isLoaded => _animSet != null;

  SpriteAnimSet get animSet {
    final value = _animSet;
    if (value == null) {
      throw StateError('PickupRenderEntry($variant) has not been loaded yet.');
    }
    return value;
  }

  Future<void> load(
    Images images, {
    required RenderAnimSetDefinition renderAnim,
  }) async {
    _animSet = await loader(
      images,
      renderAnim: renderAnim,
      oneShotKeys: oneShotKeys,
    );
  }
}

/// Render registry for pickups (PickupVariant -> render wiring).
class PickupRenderRegistry {
  PickupRenderRegistry({
    PickupRenderCatalog catalog = const PickupRenderCatalog(),
  }) : _catalog = catalog;

  final PickupRenderCatalog _catalog;

  // 16px art scaled to match Core collider sizes.
  static final Vector2 _collectibleScale = Vector2.all(1.0);
  static final Vector2 _restorationScale = Vector2.all(1.0);

  final Map<int, PickupRenderEntry> _entries = <int, PickupRenderEntry>{
    // Collectible coin.
    PickupVariant.collectible: PickupRenderEntry(
      variant: PickupVariant.collectible,
      renderScale: _collectibleScale,
    ),
    // Restoration gems.
    PickupVariant.restorationHealth: PickupRenderEntry(
      variant: PickupVariant.restorationHealth,
      renderScale: _restorationScale,
    ),
    PickupVariant.restorationMana: PickupRenderEntry(
      variant: PickupVariant.restorationMana,
      renderScale: _restorationScale,
    ),
    PickupVariant.restorationStamina: PickupRenderEntry(
      variant: PickupVariant.restorationStamina,
      renderScale: _restorationScale,
    ),
  };

  PickupRenderEntry entryForVariant(int variant) {
    final entry = _entries[variant];
    if (entry == null) {
      throw StateError(
        'No pickup render entry registered for variant=$variant.',
      );
    }
    return entry;
  }

  Future<void> load(Images images) async {
    for (final entry in _entries.values) {
      final renderAnim = _catalog.get(entry.variant);
      await entry.load(images, renderAnim: renderAnim);
    }
  }
}
