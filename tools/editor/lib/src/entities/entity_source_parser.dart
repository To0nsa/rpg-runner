// Source-backed parser entrypoint for the entities workflow.
//
// This file defines the stable parser contract and authoritative source-path
// map. Domain-specific AST walkers and const/render helpers live in part files
// so callers only depend on one parsing seam.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'entity_domain_models.dart';

part 'parser/entity_source_parser_domain_loaders.dart';
part 'parser/entity_source_parser_render_resolver.dart';
part 'parser/entity_source_parser_support.dart';

/// Parsed entity workspace snapshot produced by [EntitySourceParser].
///
/// The parser never throws for ordinary source-shape problems; it returns the
/// entries it could resolve plus [issues] describing anything the route should
/// surface before export.
class EntityParseResult {
  const EntityParseResult({
    required this.entries,
    required this.issues,
    required this.runtimeGridCellSize,
  });

  final List<EntityEntry> entries;
  final List<ValidationIssue> issues;
  final double runtimeGridCellSize;
}

/// Parses authoritative runtime Dart sources into immutable entity editor data.
///
/// This parser is intentionally aware of the current runtime authoring seams
/// for enemies, players, projectiles, render metadata, and render scale. It
/// also captures exact source bindings so later export can reject drift rather
/// than guessing how to rewrite files.
class EntitySourceParser {
  static const String enemyCatalogPath =
      'packages/runner_core/lib/enemies/enemy_catalog.dart';
  static const String playerCharactersDir =
      'packages/runner_core/lib/players/characters';
  static const String projectileCatalogPath =
      'packages/runner_core/lib/projectiles/projectile_catalog.dart';
  static const String projectileRenderCatalogPath =
      'packages/runner_core/lib/projectiles/projectile_render_catalog.dart';
  static const String enemyRenderRegistryPath =
      'lib/game/components/enemies/enemy_render_registry.dart';
  static const String projectileRenderRegistryPath =
      'lib/game/components/projectiles/projectile_render_registry.dart';
  static const String playerRenderTuningPath =
      'lib/game/tuning/player_render_tuning.dart';
  static const String spatialGridTuningPath =
      'packages/runner_core/lib/tuning/spatial_grid_tuning.dart';

  /// Fallback broadphase grid size, in world pixels, when tuning is absent.
  static const double defaultRuntimeGridCellSize = 32.0;

  /// Reads every entities-domain source file from [workspace].
  ///
  /// The result is immutable and safe for the plugin/session layer to keep as
  /// the authoritative loaded snapshot until the next reload.
  EntityParseResult parse(EditorWorkspace workspace) {
    final entries = <EntityEntry>[];
    final issues = <ValidationIssue>[];
    final renderScaleConfig = _parseRenderScaleConfig(workspace);
    final runtimeGridCellSize =
        _parseRuntimeGridCellSize(workspace) ?? defaultRuntimeGridCellSize;
    final projectileReferenceVisualById = _parseProjectileReferenceVisuals(
      workspace,
      issues,
    );

    entries.addAll(
      _parseEnemies(
        workspace,
        issues,
        enemyRenderScaleById: renderScaleConfig.enemyById,
      ),
    );
    entries.addAll(
      _parsePlayers(
        workspace,
        issues,
        playerRenderScale: renderScaleConfig.playerScale,
      ),
    );
    entries.addAll(
      _parseProjectiles(
        workspace,
        issues,
        projectileReferenceVisualById: projectileReferenceVisualById,
        projectileRenderScaleById: renderScaleConfig.projectileById,
      ),
    );

    _validateUniqueIds(entries, issues);
    return EntityParseResult(
      entries: entries,
      issues: issues,
      runtimeGridCellSize: runtimeGridCellSize,
    );
  }
}
