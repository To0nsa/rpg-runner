/// Aggregate tuning configuration for the game simulation core.
///
/// This class bundles all tuning parameters into a single object, simplifying
/// the [GameCore] constructor API. All fields have sensible defaults, so you
/// only need to override what you want to customize.

library;

import 'camera_tuning.dart';
import 'collectible_tuning.dart';
import 'flying_enemy_tuning.dart';
import 'ground_enemy_tuning.dart';
import 'navigation_tuning.dart';
import 'physics_tuning.dart';
import 'restoration_item_tuning.dart';
import 'score_tuning.dart';
import 'spatial_grid_tuning.dart';
import 'track_tuning.dart';

/// Aggregate container for all game simulation tuning parameters.
///
/// Provides a cleaner API than passing 15+ individual tuning objects to
/// [GameCore]. All fields default to their respective tuning class defaults.
class CoreTuning {
  /// Creates a core tuning configuration with optional overrides.
  ///
  /// Any parameter not specified uses its default value.
  const CoreTuning({
    this.physics = const PhysicsTuning(),
    this.unocoDemon = const UnocoDemonTuning(),
    this.groundEnemy = const GroundEnemyTuning(),
    this.navigation = const NavigationTuning(),
    this.spatialGrid = const SpatialGridTuning(),
    this.camera = const CameraTuning(),
    this.track = const TrackTuning(),
    this.collectible = const CollectibleTuning(),
    this.restorationItem = const RestorationItemTuning(),
    this.score = const ScoreTuning(),
  });

  /// Physics constants (gravity, etc.).
  final PhysicsTuning physics;

  /// Flying enemy AI and spawn parameters.
  final UnocoDemonTuning unocoDemon;

  /// Ground enemy AI and movement parameters.
  final GroundEnemyTuning groundEnemy;

  /// Pathfinding and navigation parameters.
  final NavigationTuning navigation;

  /// Spatial partitioning grid settings.
  final SpatialGridTuning spatialGrid;

  /// Camera behavior (autoscroll, smoothing).
  final CameraTuning camera;

  /// Track streaming and chunk generation.
  final TrackTuning track;

  /// Collectible spawn density and placement.
  final CollectibleTuning collectible;

  /// Restoration item spawn frequency and sizing.
  final RestorationItemTuning restorationItem;

  /// Score calculation parameters.
  final ScoreTuning score;
}
