// Domain-specific entity source loaders.
//
// Each loader understands one authoritative runtime source shape and converts
// it into editor entries plus exact source bindings. The parser stays strict on
// contracts here because export later depends on those captured ranges.
part of '../entity_source_parser.dart';

List<EntityEntry> _parseEnemies(
  EditorWorkspace workspace,
  List<ValidationIssue> issues, {
  required Map<String, _ResolvedScalarValue> enemyRenderScaleById,
}) {
  final source = _readSource(
    workspace,
    EntitySourceParser.enemyCatalogPath,
    issues,
  );
  if (source == null) {
    return const <EntityEntry>[];
  }

  final unit = _parseUnit(source, EntitySourceParser.enemyCatalogPath, issues);
  final resolver = _ConstValueResolver(
    unit: unit,
    sourcePath: EntitySourceParser.enemyCatalogPath,
    sourceContent: source,
  );
  final getMethod = _findEnemyCatalogGetMethod(unit);
  if (getMethod == null) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'enemy_get_missing',
        message: 'Could not locate EnemyCatalog.get(EnemyId) method.',
        sourcePath: EntitySourceParser.enemyCatalogPath,
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
        sourcePath: EntitySourceParser.enemyCatalogPath,
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
          sourcePath: EntitySourceParser.enemyCatalogPath,
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
          sourcePath: EntitySourceParser.enemyCatalogPath,
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
      sourcePath: EntitySourceParser.enemyCatalogPath,
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
        sourcePath: EntitySourceParser.enemyCatalogPath,
        sourceBinding: EntitySourceBinding(
          kind: EntitySourceBindingKind.enemyAabbExpression,
          sourcePath: EntitySourceParser.enemyCatalogPath,
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
  final directory = Directory(
    workspace.resolve(EntitySourceParser.playerCharactersDir),
  );
  if (!directory.existsSync()) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'player_dir_missing',
        message: 'Player character directory does not exist.',
        sourcePath: EntitySourceParser.playerCharactersDir,
      ),
    );
    return const <EntityEntry>[];
  }

  final entries = <EntityEntry>[];
  final playerFiles =
      directory
          .listSync()
          .whereType<File>()
          .where((entity) => entity.path.toLowerCase().endsWith('.dart'))
          .toList(growable: false)
        // Keep player discovery stable across filesystems so scene order,
        // pending diffs, and tests do not vary by directory enumeration order.
        ..sort((a, b) => p.normalize(a.path).compareTo(p.normalize(b.path)));
  for (final entity in playerFiles) {
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
        final colliderBinding = _bindingFromNodes(
          sourcePath: relativePath,
          source: source,
          kind: EntitySourceBindingKind.playerArgs,
          nodes: <AstNode>[widthArg, heightArg, offsetXArg, offsetYArg],
        );
        if (colliderBinding == null) {
          issues.add(
            ValidationIssue(
              severity: ValidationSeverity.error,
              code: 'player_collider_binding_invalid',
              message:
                  'Player catalog ${variable.name.lexeme} collider source range '
                  'could not be resolved.',
              sourcePath: relativePath,
            ),
          );
          continue;
        }
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
            sourceBinding: colliderBinding,
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
  final source = _readSource(
    workspace,
    EntitySourceParser.projectileCatalogPath,
    issues,
  );
  if (source == null) {
    return const <EntityEntry>[];
  }

  final unit = _parseUnit(
    source,
    EntitySourceParser.projectileCatalogPath,
    issues,
  );
  final getMethod = _findProjectileCatalogGetMethod(unit);
  if (getMethod == null) {
    issues.add(
      const ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'projectile_get_missing',
        message: 'Could not locate ProjectileCatalog.get(ProjectileId) method.',
        sourcePath: EntitySourceParser.projectileCatalogPath,
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
        sourcePath: EntitySourceParser.projectileCatalogPath,
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
          sourcePath: EntitySourceParser.projectileCatalogPath,
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
          sourcePath: EntitySourceParser.projectileCatalogPath,
        ),
      );
      continue;
    }

    final colliderBinding = _bindingFromNodes(
      sourcePath: EntitySourceParser.projectileCatalogPath,
      source: source,
      kind: EntitySourceBindingKind.projectileArgs,
      nodes: <AstNode>[sizeXArg, sizeYArg],
    );
    if (colliderBinding == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'projectile_collider_binding_invalid',
          message:
              'Projectile $projectileName collider source range could not be '
              'resolved.',
          sourcePath: EntitySourceParser.projectileCatalogPath,
        ),
      );
      continue;
    }
    final parsedReferenceVisual = projectileReferenceVisualById[projectileName];
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
        sourcePath: EntitySourceParser.projectileCatalogPath,
        sourceBinding: colliderBinding,
        referenceVisual: referenceVisual,
      ),
    );
  }
  return entries;
}

// Projectile preview metadata lives in a separate render catalog from collider
// data, so the parser resolves that source independently and joins it by id.
Map<String, EntityReferenceVisual> _parseProjectileReferenceVisuals(
  EditorWorkspace workspace,
  List<ValidationIssue> issues,
) {
  final source = _readSource(
    workspace,
    EntitySourceParser.projectileRenderCatalogPath,
    issues,
  );
  if (source == null) {
    return const <String, EntityReferenceVisual>{};
  }
  final unit = _parseUnit(
    source,
    EntitySourceParser.projectileRenderCatalogPath,
    issues,
  );
  final resolver = _ConstValueResolver(
    unit: unit,
    sourcePath: EntitySourceParser.projectileRenderCatalogPath,
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
        sourcePath: EntitySourceParser.projectileRenderCatalogPath,
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

// Render-scale authoring is intentionally read from the same runtime sources
// the game uses today rather than inventing a separate editor-owned config.
_RenderScaleConfig _parseRenderScaleConfig(EditorWorkspace workspace) {
  final playerScale = _parsePlayerRenderScale(workspace);
  final enemyById = _parseRegistryRenderScales(
    workspace,
    sourcePath: EntitySourceParser.enemyRenderRegistryPath,
    idPrefix: 'EnemyId',
    entryCtorName: 'EnemyRenderEntry',
  );
  final projectileById = _parseRegistryRenderScales(
    workspace,
    sourcePath: EntitySourceParser.projectileRenderRegistryPath,
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
  final source = _readOptionalSource(
    workspace,
    EntitySourceParser.playerRenderTuningPath,
  );
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
      sourcePath: EntitySourceParser.playerRenderTuningPath,
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

double? _parseRuntimeGridCellSize(EditorWorkspace workspace) {
  final source = _readOptionalSource(
    workspace,
    EntitySourceParser.spatialGridTuningPath,
  );
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
    anchorXWriteBinding: reference.anchorXWriteBinding,
    anchorYWriteBinding: reference.anchorYWriteBinding,
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
