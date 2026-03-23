import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../domain/authoring_types.dart';
import '../workspace/editor_workspace.dart';
import 'entity_domain_models.dart';

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
  static const double defaultRuntimeGridCellSize = 32.0;

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

  List<EntityEntry> _parseEnemies(
    EditorWorkspace workspace,
    List<ValidationIssue> issues, {
    required Map<String, _ResolvedScalarValue> enemyRenderScaleById,
  }) {
    final source = _readSource(workspace, enemyCatalogPath, issues);
    if (source == null) {
      return const <EntityEntry>[];
    }

    final unit = _parseUnit(source, enemyCatalogPath, issues);
    final resolver = _ConstValueResolver(
      unit: unit,
      parser: this,
      sourcePath: enemyCatalogPath,
      sourceContent: source,
    );
    final getMethod = _findEnemyCatalogGetMethod(unit);
    if (getMethod == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'enemy_get_missing',
          message: 'Could not locate EnemyCatalog.get(EnemyId) method.',
          sourcePath: enemyCatalogPath,
        ),
      );
      return const <EntityEntry>[];
    }

    final switchStmt = _findFirstSwitch(getMethod.body);
    if (switchStmt == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'enemy_switch_missing',
          message: 'EnemyCatalog.get(EnemyId) does not contain a switch block.',
          sourcePath: enemyCatalogPath,
        ),
      );
      return const <EntityEntry>[];
    }

    final entries = <EntityEntry>[];
    for (final member in switchStmt.members) {
      if (member is! SwitchPatternCase && member is! SwitchCase) {
        continue;
      }

      final enemyName = _switchMemberCaseName(member);
      if (enemyName == null) {
        continue;
      }

      final returnExpr = _findReturnedInstance(member.statements);
      if (returnExpr == null) {
        continue;
      }

      final colliderExpr = _namedArgumentExpression(
        returnExpr.argumentList.arguments,
        'collider',
      );
      final colliderValueExpr = colliderExpr;
      NodeList<Expression>? colliderArgs;
      if (colliderValueExpr is InstanceCreationExpression) {
        colliderArgs = colliderValueExpr.argumentList.arguments;
      } else if (colliderValueExpr is MethodInvocation &&
          colliderValueExpr.methodName.name == 'ColliderAabbDef') {
        colliderArgs = colliderValueExpr.argumentList.arguments;
      }
      if (colliderArgs == null || colliderValueExpr == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'enemy_collider_missing',
            message: 'Enemy $enemyName has no ColliderAabbDef collider.',
            sourcePath: enemyCatalogPath,
          ),
        );
        continue;
      }

      final halfX = _doubleNamedArg(colliderArgs, 'halfX');
      final halfY = _doubleNamedArg(colliderArgs, 'halfY');
      if (halfX == null || halfY == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'enemy_half_extents_missing',
            message:
                'Enemy $enemyName collider is missing halfX/halfY numeric values.',
            sourcePath: enemyCatalogPath,
          ),
        );
        continue;
      }
      final offsetX = _doubleNamedArg(colliderArgs, 'offsetX') ?? 0.0;
      final offsetY = _doubleNamedArg(colliderArgs, 'offsetY') ?? 0.0;
      final artFacingDirection =
          _facingFromExpression(
            _namedArgumentExpression(
              returnExpr.argumentList.arguments,
              'artFacingDir',
            ),
          ) ??
          EntityArtFacingDirection.left;
      final castOriginOffsetArg = _namedArgument(
        returnExpr.argumentList.arguments,
        'castOriginOffset',
      );
      final castOriginOffset = castOriginOffsetArg == null
          ? null
          : _doubleFromExpression(castOriginOffsetArg.expression);
      final castOriginOffsetBinding = _scalarBindingFromNamedArg(
        sourcePath: enemyCatalogPath,
        source: source,
        kind: EntitySourceBindingKind.castOriginOffsetScalar,
        namedArg: castOriginOffsetArg,
      );
      final isCaster =
          _hasNonNullNamedArgument(
            returnExpr.argumentList.arguments,
            'primaryCastAbilityId',
          ) ||
          castOriginOffset != null;

      final start = colliderValueExpr.offset;
      final end = colliderValueExpr.end;
      final renderAnimExpression = _namedArgumentExpression(
        returnExpr.argumentList.arguments,
        'renderAnim',
      );
      final parsedReferenceVisual = renderAnimExpression == null
          ? null
          : resolver.resolveRenderVisual(renderAnimExpression);
      final referenceVisual = _withRenderScale(
        parsedReferenceVisual,
        enemyRenderScaleById[enemyName],
      );
      entries.add(
        EntityEntry(
          id: 'enemy.$enemyName',
          label: 'Enemy: ${_titleCaseCamel(enemyName)}',
          entityType: EntityType.enemy,
          halfX: halfX,
          halfY: halfY,
          offsetX: offsetX,
          offsetY: offsetY,
          sourcePath: enemyCatalogPath,
          sourceBinding: EntitySourceBinding(
            kind: EntitySourceBindingKind.enemyAabbExpression,
            sourcePath: enemyCatalogPath,
            startOffset: start,
            endOffset: end,
            sourceSnippet: source.substring(start, end),
          ),
          referenceVisual: referenceVisual,
          artFacingDirection: artFacingDirection,
          isCaster: isCaster,
          castOriginOffset: castOriginOffset,
          castOriginOffsetBinding: castOriginOffsetBinding,
        ),
      );
    }

    return entries;
  }

  List<EntityEntry> _parsePlayers(
    EditorWorkspace workspace,
    List<ValidationIssue> issues, {
    required _ResolvedScalarValue? playerRenderScale,
  }) {
    final directory = Directory(workspace.resolve(playerCharactersDir));
    if (!directory.existsSync()) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'player_dir_missing',
          message: 'Player character directory does not exist.',
          sourcePath: playerCharactersDir,
        ),
      );
      return const <EntityEntry>[];
    }

    final entries = <EntityEntry>[];
    for (final entity in directory.listSync().whereType<File>()) {
      if (!entity.path.toLowerCase().endsWith('.dart')) {
        continue;
      }
      final absPath = p.normalize(entity.path);
      final relativePath = p.normalize(
        p.relative(absPath, from: workspace.rootPath),
      );
      final source = _readAbsoluteSource(absPath, relativePath, issues);
      if (source == null) {
        continue;
      }
      final unit = _parseUnit(source, relativePath, issues);
      final resolver = _ConstValueResolver(
        unit: unit,
        parser: this,
        sourcePath: relativePath,
        sourceContent: source,
      );

      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>()) {
        final list = declaration.variables;
        final keyword = list.keyword?.lexeme;
        if (keyword != 'const') {
          continue;
        }
        for (final variable in list.variables) {
          final initializer = variable.initializer;
          NodeList<Expression>? args;
          if (initializer is InstanceCreationExpression) {
            final createdType = initializer.constructorName.type.toSource();
            if (createdType != 'PlayerCatalog') {
              continue;
            }
            args = initializer.argumentList.arguments;
          } else if (initializer is MethodInvocation &&
              initializer.methodName.name == 'PlayerCatalog') {
            args = initializer.argumentList.arguments;
          }
          if (args == null) {
            continue;
          }

          final widthArg = _namedArgument(args, 'colliderWidth');
          final heightArg = _namedArgument(args, 'colliderHeight');
          final offsetXArg = _namedArgument(args, 'colliderOffsetX');
          final offsetYArg = _namedArgument(args, 'colliderOffsetY');
          if (widthArg == null ||
              heightArg == null ||
              offsetXArg == null ||
              offsetYArg == null) {
            issues.add(
              ValidationIssue(
                severity: ValidationSeverity.warning,
                code: 'player_collider_args_missing',
                message:
                    'Player catalog ${variable.name.lexeme} is missing one or '
                    'more collider args.',
                sourcePath: relativePath,
              ),
            );
            continue;
          }

          final width = _doubleFromExpression(widthArg.expression);
          final height = _doubleFromExpression(heightArg.expression);
          final offsetX = _doubleFromExpression(offsetXArg.expression);
          final offsetY = _doubleFromExpression(offsetYArg.expression);
          if (width == null ||
              height == null ||
              offsetX == null ||
              offsetY == null) {
            issues.add(
              ValidationIssue(
                severity: ValidationSeverity.error,
                code: 'player_collider_non_numeric',
                message:
                    'Player catalog ${variable.name.lexeme} collider values must '
                    'be numeric literals.',
                sourcePath: relativePath,
              ),
            );
            continue;
          }

          final artFacingDirection =
              _facingFromExpression(_namedArgumentExpression(args, 'facing')) ??
              EntityArtFacingDirection.right;
          final castOriginOffsetArg = _namedArgument(args, 'castOriginOffset');
          final castOriginOffset = castOriginOffsetArg == null
              ? null
              : _doubleFromExpression(castOriginOffsetArg.expression);
          final castOriginOffsetBinding = _scalarBindingFromNamedArg(
            sourcePath: relativePath,
            source: source,
            kind: EntitySourceBindingKind.castOriginOffsetScalar,
            namedArg: castOriginOffsetArg,
          );
          final isCaster =
              _hasNonNullNamedArgument(args, 'abilityProjectileId') ||
              _hasNonNullNamedArgument(args, 'abilitySpellId') ||
              castOriginOffset != null;
          final idBase = _playerIdFromCatalogVariable(variable.name.lexeme);
          final parsedReferenceVisual = resolver.resolveRenderVisualByName(
            '${idBase}RenderAnim',
          );
          final referenceVisual = _withRenderScale(
            parsedReferenceVisual,
            playerRenderScale,
          );
          final start = widthArg.offset;
          final end = offsetYArg.end;
          entries.add(
            EntityEntry(
              id: 'player.$idBase',
              label: 'Player: ${_titleCaseCamel(idBase)}',
              entityType: EntityType.player,
              halfX: width * 0.5,
              halfY: height * 0.5,
              offsetX: offsetX,
              offsetY: offsetY,
              sourcePath: relativePath,
              sourceBinding: EntitySourceBinding(
                kind: EntitySourceBindingKind.playerArgs,
                sourcePath: relativePath,
                startOffset: start,
                endOffset: end,
                sourceSnippet: source.substring(start, end),
              ),
              referenceVisual: referenceVisual,
              artFacingDirection: artFacingDirection,
              isCaster: isCaster,
              castOriginOffset: castOriginOffset,
              castOriginOffsetBinding: castOriginOffsetBinding,
            ),
          );
        }
      }
    }
    return entries;
  }

  List<EntityEntry> _parseProjectiles(
    EditorWorkspace workspace,
    List<ValidationIssue> issues, {
    required Map<String, EntityReferenceVisual> projectileReferenceVisualById,
    required Map<String, _ResolvedScalarValue> projectileRenderScaleById,
  }) {
    final source = _readSource(workspace, projectileCatalogPath, issues);
    if (source == null) {
      return const <EntityEntry>[];
    }

    final unit = _parseUnit(source, projectileCatalogPath, issues);
    final getMethod = _findProjectileCatalogGetMethod(unit);
    if (getMethod == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'projectile_get_missing',
          message:
              'Could not locate ProjectileCatalog.get(ProjectileId) method.',
          sourcePath: projectileCatalogPath,
        ),
      );
      return const <EntityEntry>[];
    }

    final switchStmt = _findFirstSwitch(getMethod.body);
    if (switchStmt == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'projectile_switch_missing',
          message:
              'ProjectileCatalog.get(ProjectileId) does not contain a switch block.',
          sourcePath: projectileCatalogPath,
        ),
      );
      return const <EntityEntry>[];
    }

    final entries = <EntityEntry>[];
    for (final member in switchStmt.members) {
      if (member is! SwitchPatternCase && member is! SwitchCase) {
        continue;
      }
      final projectileName = _switchMemberCaseName(member);
      if (projectileName == null || projectileName == 'unknown') {
        continue;
      }

      final returnExpr = _findReturnedInstance(member.statements);
      if (returnExpr == null) {
        continue;
      }

      final sizeXArg = _namedArgument(
        returnExpr.argumentList.arguments,
        'colliderSizeX',
      );
      final sizeYArg = _namedArgument(
        returnExpr.argumentList.arguments,
        'colliderSizeY',
      );
      if (sizeXArg == null || sizeYArg == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'projectile_collider_missing',
            message: 'Projectile $projectileName is missing colliderSizeX/Y.',
            sourcePath: projectileCatalogPath,
          ),
        );
        continue;
      }

      final sizeX = _doubleFromExpression(sizeXArg.expression);
      final sizeY = _doubleFromExpression(sizeYArg.expression);
      if (sizeX == null || sizeY == null) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'projectile_collider_non_numeric',
            message:
                'Projectile $projectileName colliderSizeX/Y must be numeric.',
            sourcePath: projectileCatalogPath,
          ),
        );
        continue;
      }

      final start = sizeXArg.offset;
      final end = sizeYArg.end;
      final parsedReferenceVisual =
          projectileReferenceVisualById[projectileName];
      final referenceVisual = _withRenderScale(
        parsedReferenceVisual,
        projectileRenderScaleById[projectileName],
      );
      entries.add(
        EntityEntry(
          id: 'projectile.$projectileName',
          label: 'Projectile: ${_titleCaseCamel(projectileName)}',
          entityType: EntityType.projectile,
          halfX: sizeX * 0.5,
          halfY: sizeY * 0.5,
          offsetX: 0.0,
          offsetY: 0.0,
          sourcePath: projectileCatalogPath,
          sourceBinding: EntitySourceBinding(
            kind: EntitySourceBindingKind.projectileArgs,
            sourcePath: projectileCatalogPath,
            startOffset: start,
            endOffset: end,
            sourceSnippet: source.substring(start, end),
          ),
          referenceVisual: referenceVisual,
        ),
      );
    }
    return entries;
  }

  Map<String, EntityReferenceVisual> _parseProjectileReferenceVisuals(
    EditorWorkspace workspace,
    List<ValidationIssue> issues,
  ) {
    final source = _readSource(workspace, projectileRenderCatalogPath, issues);
    if (source == null) {
      return const <String, EntityReferenceVisual>{};
    }
    final unit = _parseUnit(source, projectileRenderCatalogPath, issues);
    final resolver = _ConstValueResolver(
      unit: unit,
      parser: this,
      sourcePath: projectileRenderCatalogPath,
      sourceContent: source,
    );
    final getMethod = _findProjectileRenderCatalogGetMethod(unit);
    if (getMethod == null) {
      issues.add(
        const ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'projectile_render_get_missing',
          message:
              'Could not locate ProjectileRenderCatalog.get(ProjectileId) method.',
          sourcePath: projectileRenderCatalogPath,
        ),
      );
      return const <String, EntityReferenceVisual>{};
    }
    final switchStmt = _findFirstSwitch(getMethod.body);
    if (switchStmt == null) {
      return const <String, EntityReferenceVisual>{};
    }

    final visualById = <String, EntityReferenceVisual>{};
    for (final member in switchStmt.members) {
      if (member is! SwitchPatternCase && member is! SwitchCase) {
        continue;
      }
      final projectileName = _switchMemberCaseName(member);
      if (projectileName == null || projectileName == 'unknown') {
        continue;
      }
      final returnedExpression = _findReturnedExpression(member.statements);
      if (returnedExpression == null) {
        continue;
      }
      final visual = resolver.resolveRenderVisual(returnedExpression);
      if (visual != null) {
        visualById[projectileName] = visual;
      }
    }
    return visualById;
  }

  _RenderScaleConfig _parseRenderScaleConfig(EditorWorkspace workspace) {
    final playerScale = _parsePlayerRenderScale(workspace);
    final enemyById = _parseRegistryRenderScales(
      workspace,
      sourcePath: enemyRenderRegistryPath,
      idPrefix: 'EnemyId',
      entryCtorName: 'EnemyRenderEntry',
    );
    final projectileById = _parseRegistryRenderScales(
      workspace,
      sourcePath: projectileRenderRegistryPath,
      idPrefix: 'ProjectileId',
      entryCtorName: 'ProjectileRenderEntry',
    );
    return _RenderScaleConfig(
      playerScale: playerScale,
      enemyById: enemyById,
      projectileById: projectileById,
    );
  }

  _ResolvedScalarValue? _parsePlayerRenderScale(EditorWorkspace workspace) {
    final source = _readOptionalSource(workspace, playerRenderTuningPath);
    if (source == null) {
      return null;
    }
    final match = RegExp(
      r'this\.scale\s*=\s*(-?[0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(source);
    if (match == null) {
      return null;
    }
    final value = double.tryParse(match.group(1)!);
    if (value == null) {
      return null;
    }
    final fullMatch = match.group(0)!;
    final valueMatch = match.group(1)!;
    final valueIndexInFull = fullMatch.indexOf(valueMatch);
    if (valueIndexInFull < 0) {
      return null;
    }
    final start = match.start + valueIndexInFull;
    final end = start + valueMatch.length;
    return _ResolvedScalarValue(
      value: value,
      binding: EntitySourceBinding(
        kind: EntitySourceBindingKind.referenceRenderScaleScalar,
        sourcePath: playerRenderTuningPath,
        startOffset: start,
        endOffset: end,
        sourceSnippet: source.substring(start, end),
      ),
    );
  }

  Map<String, _ResolvedScalarValue> _parseRegistryRenderScales(
    EditorWorkspace workspace, {
    required String sourcePath,
    required String idPrefix,
    required String entryCtorName,
  }) {
    final source = _readOptionalSource(workspace, sourcePath);
    if (source == null) {
      return const <String, _ResolvedScalarValue>{};
    }
    final pattern = RegExp(
      '$idPrefix\\.(\\w+)\\s*:\\s*$entryCtorName\\([\\s\\S]*?'
      'renderScale\\s*:\\s*Vector2\\.all\\(\\s*(-?[0-9]+(?:\\.[0-9]+)?)\\s*\\)',
      multiLine: true,
    );
    final map = <String, _ResolvedScalarValue>{};
    for (final match in pattern.allMatches(source)) {
      final id = match.group(1);
      final scaleRaw = match.group(2);
      if (id == null || scaleRaw == null) {
        continue;
      }
      final scale = double.tryParse(scaleRaw);
      if (scale == null) {
        continue;
      }
      final fullMatch = match.group(0)!;
      final scaleIndexInFull = fullMatch.indexOf(scaleRaw);
      if (scaleIndexInFull < 0) {
        continue;
      }
      final start = match.start + scaleIndexInFull;
      final end = start + scaleRaw.length;
      map[id] = _ResolvedScalarValue(
        value: scale,
        binding: EntitySourceBinding(
          kind: EntitySourceBindingKind.referenceRenderScaleScalar,
          sourcePath: sourcePath,
          startOffset: start,
          endOffset: end,
          sourceSnippet: source.substring(start, end),
        ),
      );
    }
    return map;
  }

  String? _readOptionalSource(EditorWorkspace workspace, String relativePath) {
    final file = File(workspace.resolve(relativePath));
    if (!file.existsSync()) {
      return null;
    }
    try {
      return file.readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  double? _parseRuntimeGridCellSize(EditorWorkspace workspace) {
    final source = _readOptionalSource(workspace, spatialGridTuningPath);
    if (source == null) {
      return null;
    }
    final match = RegExp(
      r'this\.broadphaseCellSize\s*=\s*(-?[0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(source);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1)!);
  }

  EntityReferenceVisual? _withRenderScale(
    EntityReferenceVisual? reference,
    _ResolvedScalarValue? renderScale,
  ) {
    if (reference == null || renderScale == null) {
      return reference;
    }
    return EntityReferenceVisual(
      assetPath: reference.assetPath,
      frameWidth: reference.frameWidth,
      frameHeight: reference.frameHeight,
      anchorXPx: reference.anchorXPx,
      anchorYPx: reference.anchorYPx,
      anchorBinding: reference.anchorBinding,
      renderScale: renderScale.value,
      renderScaleBinding: renderScale.binding,
      defaultRow: reference.defaultRow,
      defaultFrameStart: reference.defaultFrameStart,
      defaultFrameCount: reference.defaultFrameCount,
      defaultGridColumns: reference.defaultGridColumns,
      defaultAnimKey: reference.defaultAnimKey,
      animViewsByKey: reference.animViewsByKey,
    );
  }

  String? _readSource(
    EditorWorkspace workspace,
    String relativePath,
    List<ValidationIssue> issues,
  ) {
    return _readAbsoluteSource(
      workspace.resolve(relativePath),
      relativePath,
      issues,
    );
  }

  String? _readAbsoluteSource(
    String absolutePath,
    String relativePath,
    List<ValidationIssue> issues,
  ) {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'source_file_missing',
          message: 'Source file not found: $relativePath',
          sourcePath: relativePath,
        ),
      );
      return null;
    }
    try {
      return file.readAsStringSync();
    } catch (error) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'source_read_failed',
          message: 'Failed to read $relativePath: $error',
          sourcePath: relativePath,
        ),
      );
      return null;
    }
  }

  CompilationUnit _parseUnit(
    String source,
    String sourcePath,
    List<ValidationIssue> issues,
  ) {
    final result = parseString(
      content: source,
      path: sourcePath,
      throwIfDiagnostics: false,
    );
    if (result.errors.isNotEmpty) {
      for (final error in result.errors) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.warning,
            code: 'parse_diagnostic',
            message: 'Parse diagnostic in $sourcePath: ${error.message}',
            sourcePath: sourcePath,
          ),
        );
      }
    }
    return result.unit;
  }

  MethodDeclaration? _findEnemyCatalogGetMethod(CompilationUnit unit) {
    final enemyCatalogClass = unit.declarations
        .whereType<ClassDeclaration>()
        .where((declaration) => declaration.name.lexeme == 'EnemyCatalog')
        .firstOrNull;
    if (enemyCatalogClass == null) {
      return null;
    }
    return enemyCatalogClass.members
        .whereType<MethodDeclaration>()
        .where((method) => method.name.lexeme == 'get')
        .firstOrNull;
  }

  MethodDeclaration? _findProjectileCatalogGetMethod(CompilationUnit unit) {
    final projectileCatalogClass = unit.declarations
        .whereType<ClassDeclaration>()
        .where((declaration) => declaration.name.lexeme == 'ProjectileCatalog')
        .firstOrNull;
    if (projectileCatalogClass == null) {
      return null;
    }
    return projectileCatalogClass.members
        .whereType<MethodDeclaration>()
        .where((method) => method.name.lexeme == 'get')
        .firstOrNull;
  }

  MethodDeclaration? _findProjectileRenderCatalogGetMethod(
    CompilationUnit unit,
  ) {
    final renderCatalogClass = unit.declarations
        .whereType<ClassDeclaration>()
        .where(
          (declaration) => declaration.name.lexeme == 'ProjectileRenderCatalog',
        )
        .firstOrNull;
    if (renderCatalogClass == null) {
      return null;
    }
    return renderCatalogClass.members
        .whereType<MethodDeclaration>()
        .where((method) => method.name.lexeme == 'get')
        .firstOrNull;
  }

  SwitchStatement? _findFirstSwitch(FunctionBody body) {
    if (body is! BlockFunctionBody) {
      return null;
    }
    for (final statement in body.block.statements) {
      if (statement is SwitchStatement) {
        return statement;
      }
    }
    return null;
  }

  String? _switchMemberCaseName(SwitchMember member) {
    if (member is SwitchCase) {
      return _enumCaseName(member.expression);
    }
    if (member is SwitchPatternCase) {
      final label = member.guardedPattern.pattern;
      if (label is ConstantPattern) {
        return _enumCaseName(label.expression);
      }
    }
    return null;
  }

  String? _enumCaseName(Expression expression) {
    if (expression is PrefixedIdentifier) {
      return expression.identifier.name;
    }
    if (expression is PropertyAccess) {
      return expression.propertyName.name;
    }
    return null;
  }

  InstanceCreationExpression? _findReturnedInstance(
    List<Statement> statements,
  ) {
    for (final statement in statements) {
      if (statement is ReturnStatement &&
          statement.expression is InstanceCreationExpression) {
        return statement.expression as InstanceCreationExpression;
      }
    }
    return null;
  }

  Expression? _findReturnedExpression(List<Statement> statements) {
    for (final statement in statements) {
      if (statement is ReturnStatement) {
        return statement.expression;
      }
    }
    return null;
  }

  NamedExpression? _namedArgument(NodeList<Expression> arguments, String name) {
    for (final argument in arguments) {
      if (argument is! NamedExpression) {
        continue;
      }
      if (argument.name.label.name == name) {
        return argument;
      }
    }
    return null;
  }

  Expression? _namedArgumentExpression(
    NodeList<Expression> arguments,
    String name,
  ) {
    return _namedArgument(arguments, name)?.expression;
  }

  double? _doubleNamedArg(NodeList<Expression> arguments, String name) {
    final expression = _namedArgumentExpression(arguments, name);
    if (expression == null) {
      return null;
    }
    return _doubleFromExpression(expression);
  }

  bool _hasNonNullNamedArgument(NodeList<Expression> arguments, String name) {
    final expression = _namedArgumentExpression(arguments, name);
    if (expression == null) {
      return false;
    }
    return expression is! NullLiteral;
  }

  EntityArtFacingDirection? _facingFromExpression(Expression? expression) {
    if (expression == null) {
      return null;
    }
    final value = _enumCaseName(expression);
    return switch (value) {
      'left' => EntityArtFacingDirection.left,
      'right' => EntityArtFacingDirection.right,
      _ => null,
    };
  }

  EntitySourceBinding? _scalarBindingFromNamedArg({
    required String sourcePath,
    required String source,
    required EntitySourceBindingKind kind,
    required NamedExpression? namedArg,
  }) {
    final expression = namedArg?.expression;
    if (expression == null) {
      return null;
    }
    final start = expression.offset;
    final end = expression.end;
    if (start < 0 || end <= start || end > source.length) {
      return null;
    }
    return EntitySourceBinding(
      kind: kind,
      sourcePath: sourcePath,
      startOffset: start,
      endOffset: end,
      sourceSnippet: source.substring(start, end),
    );
  }

  double? _doubleFromExpression(Expression expression) {
    if (expression is DoubleLiteral) {
      return expression.value;
    }
    if (expression is IntegerLiteral) {
      return expression.value?.toDouble();
    }
    if (expression is PrefixExpression &&
        expression.operator.lexeme == '-' &&
        expression.operand is IntegerLiteral) {
      final operand = expression.operand as IntegerLiteral;
      return -(operand.value?.toDouble() ?? 0.0);
    }
    if (expression is PrefixExpression &&
        expression.operator.lexeme == '-' &&
        expression.operand is DoubleLiteral) {
      final operand = expression.operand as DoubleLiteral;
      return -operand.value;
    }
    return null;
  }

  void _validateUniqueIds(
    List<EntityEntry> entries,
    List<ValidationIssue> issues,
  ) {
    final seen = <String>{};
    for (final entry in entries) {
      if (seen.contains(entry.id)) {
        issues.add(
          ValidationIssue(
            severity: ValidationSeverity.error,
            code: 'duplicate_entry_id',
            message: 'Duplicate collider entry id detected: ${entry.id}',
            sourcePath: entry.sourcePath,
          ),
        );
        continue;
      }
      seen.add(entry.id);
    }
  }

  String _playerIdFromCatalogVariable(String variableName) {
    if (variableName.endsWith('Catalog') &&
        variableName.length > 'Catalog'.length) {
      return variableName.substring(0, variableName.length - 'Catalog'.length);
    }
    return variableName;
  }

  String _titleCaseCamel(String value) {
    final words = value.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    if (words.isEmpty) {
      return value;
    }
    return words
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _ConstValueResolver {
  _ConstValueResolver({
    required CompilationUnit unit,
    required EntitySourceParser parser,
    required String sourcePath,
    required String sourceContent,
  }) : _parser = parser,
       _sourcePath = sourcePath,
       _sourceContent = sourceContent,
       _initializerByName = _collectConstInitializers(unit);

  final EntitySourceParser _parser;
  final String _sourcePath;
  final String _sourceContent;
  final Map<String, Expression> _initializerByName;

  EntityReferenceVisual? resolveRenderVisualByName(String variableName) {
    final expression = _initializerByName[variableName];
    if (expression == null) {
      return null;
    }
    return resolveRenderVisual(expression);
  }

  EntityReferenceVisual? resolveRenderVisual(Expression expression) {
    final resolved = _resolveExpression(expression, <String>{});
    final arguments = _renderAnimArguments(resolved);
    if (arguments == null) {
      return null;
    }

    final frameWidthExpr = _parser._namedArgumentExpression(
      arguments,
      'frameWidth',
    );
    final frameHeightExpr = _parser._namedArgumentExpression(
      arguments,
      'frameHeight',
    );
    final frameWidth = frameWidthExpr == null
        ? null
        : _resolveDouble(frameWidthExpr);
    final frameHeight = frameHeightExpr == null
        ? null
        : _resolveDouble(frameHeightExpr);
    final anchorPointExpr = _parser._namedArgumentExpression(
      arguments,
      'anchorPoint',
    );
    final anchorPoint = _resolveVec2(anchorPointExpr);
    final anchorBinding = _resolveExpressionBinding(
      anchorPointExpr,
      EntitySourceBindingKind.referenceAnchorVec2Expression,
    );

    final sourcesExpr = _parser._namedArgumentExpression(
      arguments,
      'sourcesByKey',
    );
    final sourceByAnimKey = sourcesExpr == null
        ? const <String, String>{}
        : _resolveAnimSourceMap(sourcesExpr);
    final rowByAnimKey = _resolveAnimIntMap(
      _parser._namedArgumentExpression(arguments, 'rowByKey'),
    );
    final frameStartByAnimKey = _resolveAnimIntMap(
      _parser._namedArgumentExpression(arguments, 'frameStartByKey'),
    );
    final frameCountByAnimKey = _resolveAnimIntMap(
      _parser._namedArgumentExpression(arguments, 'frameCountsByKey'),
    );
    final gridColumnsByAnimKey = _resolveAnimIntMap(
      _parser._namedArgumentExpression(arguments, 'gridColumnsByKey'),
    );

    final animViewsByKey = <String, EntityReferenceAnimView>{};
    for (final entry in sourceByAnimKey.entries) {
      final key = entry.key;
      final assetPath = entry.value;
      if (assetPath.isEmpty) {
        continue;
      }
      animViewsByKey[key] = EntityReferenceAnimView(
        key: key,
        assetPath: assetPath,
        row: rowByAnimKey[key] ?? 0,
        frameStart: frameStartByAnimKey[key] ?? 0,
        frameCount: frameCountByAnimKey[key],
        gridColumns: gridColumnsByAnimKey[key],
      );
    }
    final preferredAnimKey = _preferredSourceKey(sourceByAnimKey);
    final fallbackKey = animViewsByKey.isEmpty
        ? null
        : animViewsByKey.keys.first;
    final defaultAnimKey = preferredAnimKey ?? fallbackKey;
    if (defaultAnimKey == null) {
      return null;
    }
    final defaultAnimView = animViewsByKey[defaultAnimKey];
    if (defaultAnimView == null) {
      return null;
    }

    return EntityReferenceVisual(
      assetPath: defaultAnimView.assetPath,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      anchorXPx: anchorPoint?.x,
      anchorYPx: anchorPoint?.y,
      anchorBinding: anchorBinding,
      defaultRow: defaultAnimView.row,
      defaultFrameStart: defaultAnimView.frameStart,
      defaultFrameCount: defaultAnimView.frameCount,
      defaultGridColumns: defaultAnimView.gridColumns,
      defaultAnimKey: defaultAnimKey,
      animViewsByKey: animViewsByKey,
    );
  }

  EntitySourceBinding? _resolveExpressionBinding(
    Expression? expression,
    EntitySourceBindingKind kind,
  ) {
    if (expression == null) {
      return null;
    }
    final resolved = _resolveExpression(expression, <String>{});
    final start = resolved.offset;
    final end = resolved.end;
    if (start < 0 || end <= start || end > _sourceContent.length) {
      return null;
    }
    return EntitySourceBinding(
      kind: kind,
      sourcePath: _sourcePath,
      startOffset: start,
      endOffset: end,
      sourceSnippet: _sourceContent.substring(start, end),
    );
  }

  static Map<String, Expression> _collectConstInitializers(
    CompilationUnit unit,
  ) {
    final map = <String, Expression>{};
    for (final declaration
        in unit.declarations.whereType<TopLevelVariableDeclaration>()) {
      if (declaration.variables.keyword?.lexeme != 'const') {
        continue;
      }
      for (final variable in declaration.variables.variables) {
        final initializer = variable.initializer;
        if (initializer == null) {
          continue;
        }
        map[variable.name.lexeme] = initializer;
      }
    }
    return map;
  }

  Expression _resolveExpression(Expression expression, Set<String> chain) {
    if (expression is SimpleIdentifier) {
      final name = expression.name;
      if (chain.contains(name)) {
        return expression;
      }
      final initializer = _initializerByName[name];
      if (initializer == null) {
        return expression;
      }
      return _resolveExpression(initializer, <String>{...chain, name});
    }
    return expression;
  }

  NodeList<Expression>? _renderAnimArguments(Expression expression) {
    if (expression is InstanceCreationExpression &&
        expression.constructorName.type.toSource() ==
            'RenderAnimSetDefinition') {
      return expression.argumentList.arguments;
    }
    if (expression is MethodInvocation &&
        expression.methodName.name == 'RenderAnimSetDefinition') {
      return expression.argumentList.arguments;
    }
    return null;
  }

  double? _resolveDouble(Expression expression) {
    final resolved = _resolveExpression(expression, <String>{});
    final literalValue = _parser._doubleFromExpression(resolved);
    if (literalValue != null) {
      return literalValue;
    }
    if (resolved is ParenthesizedExpression) {
      return _resolveDouble(resolved.expression);
    }
    if (resolved is BinaryExpression) {
      final left = _resolveDouble(resolved.leftOperand);
      final right = _resolveDouble(resolved.rightOperand);
      if (left == null || right == null) {
        return null;
      }
      return switch (resolved.operator.lexeme) {
        '+' => left + right,
        '-' => left - right,
        '*' => left * right,
        '/' => right == 0 ? null : left / right,
        _ => null,
      };
    }
    return null;
  }

  _ResolvedVec2? _resolveVec2(Expression? expression) {
    if (expression == null) {
      return null;
    }
    final resolved = _resolveExpression(expression, <String>{});
    NodeList<Expression>? args;
    if (resolved is InstanceCreationExpression &&
        resolved.constructorName.type.toSource() == 'Vec2') {
      args = resolved.argumentList.arguments;
    } else if (resolved is MethodInvocation &&
        resolved.methodName.name == 'Vec2') {
      args = resolved.argumentList.arguments;
    }
    if (args == null || args.length < 2) {
      return null;
    }
    final x = _resolveDouble(args[0]);
    final y = _resolveDouble(args[1]);
    if (x == null || y == null) {
      return null;
    }
    return _ResolvedVec2(x: x, y: y);
  }

  String? _resolveString(Expression expression) {
    final resolved = _resolveExpression(expression, <String>{});
    if (resolved is StringLiteral) {
      return resolved.stringValue;
    }
    if (resolved is AdjacentStrings) {
      final buffer = StringBuffer();
      for (final value in resolved.strings) {
        if (value.stringValue == null) {
          return null;
        }
        buffer.write(value.stringValue);
      }
      return buffer.toString();
    }
    return null;
  }

  Map<String, String> _resolveAnimSourceMap(Expression expression) {
    final resolved = _resolveExpression(expression, <String>{});
    if (resolved is! SetOrMapLiteral) {
      return const <String, String>{};
    }

    final map = <String, String>{};
    for (final element in resolved.elements.whereType<MapLiteralEntry>()) {
      final keyName = _parser._enumCaseName(element.key);
      if (keyName == null) {
        continue;
      }
      final value = _resolveString(element.value);
      if (value == null || value.isEmpty) {
        continue;
      }
      map[keyName] = value;
    }
    return map;
  }

  Map<String, int> _resolveAnimIntMap(Expression? expression) {
    if (expression == null) {
      return const <String, int>{};
    }
    final resolved = _resolveExpression(expression, <String>{});
    if (resolved is! SetOrMapLiteral) {
      return const <String, int>{};
    }

    final map = <String, int>{};
    for (final element in resolved.elements.whereType<MapLiteralEntry>()) {
      final keyName = _parser._enumCaseName(element.key);
      if (keyName == null) {
        continue;
      }
      final value = _resolveInt(element.value);
      if (value == null) {
        continue;
      }
      map[keyName] = value;
    }
    return map;
  }

  int? _resolveInt(Expression expression) {
    final resolved = _resolveExpression(expression, <String>{});
    if (resolved is IntegerLiteral) {
      return resolved.value;
    }
    if (resolved is PrefixExpression &&
        resolved.operator.lexeme == '-' &&
        resolved.operand is IntegerLiteral) {
      final operand = resolved.operand as IntegerLiteral;
      final value = operand.value;
      return value == null ? null : -value;
    }
    return null;
  }

  String? _preferredSourceKey(Map<String, String> sourceByAnimKey) {
    const keyPriority = <String>[
      'idle',
      'spawn',
      'run',
      'walk',
      'strike',
      'cast',
      'hit',
      'death',
    ];
    for (final key in keyPriority) {
      final value = sourceByAnimKey[key];
      if (value != null && value.isNotEmpty) {
        return key;
      }
    }
    if (sourceByAnimKey.isEmpty) {
      return null;
    }
    return sourceByAnimKey.keys.first;
  }
}

class _RenderScaleConfig {
  const _RenderScaleConfig({
    required this.playerScale,
    required this.enemyById,
    required this.projectileById,
  });

  final _ResolvedScalarValue? playerScale;
  final Map<String, _ResolvedScalarValue> enemyById;
  final Map<String, _ResolvedScalarValue> projectileById;
}

class _ResolvedVec2 {
  const _ResolvedVec2({required this.x, required this.y});

  final double x;
  final double y;
}

class _ResolvedScalarValue {
  const _ResolvedScalarValue({required this.value, required this.binding});

  final double value;
  final EntitySourceBinding binding;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
