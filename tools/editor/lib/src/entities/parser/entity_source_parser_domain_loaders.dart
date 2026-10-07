// Domain-specific entity source loaders.
//
// Each loader understands one authoritative runtime source shape and converts
// it into editor entries plus exact source bindings. The parser stays strict on
// contracts here because export later depends on those captured ranges.
part of '../entity_source_parser.dart';

List<EntityEntry> _parseAutonomousActors(
  EditorWorkspace workspace,
  List<ValidationIssue> issues, {
  required String sourcePath,
  required String catalogClass,
  required EntityType entityType,
  required EntityArtFacingDirection defaultFacing,
}) {
  final source = _readSource(workspace, sourcePath, issues);
  if (source == null) return const [];
  final unit = _parseUnit(source, sourcePath, issues);
  final resolver = _ConstValueResolver(
    unit: unit,
    sourcePath: sourcePath,
    sourceContent: source,
  );
  final method = _findActorCatalogGetMethod(unit, catalogClass);
  final rows = <(String, Expression)>[];
  final body = method?.body;
  if (body is ExpressionFunctionBody && body.expression is SwitchExpression) {
    for (final member in (body.expression as SwitchExpression).cases) {
      final pattern = member.guardedPattern.pattern;
      final name = pattern is ConstantPattern
          ? _enumCaseName(pattern.expression)
          : null;
      if (name != null) rows.add((name, member.expression));
    }
  } else if (body != null) {
    final switchStatement = _findFirstSwitch(body);
    if (switchStatement != null) {
      for (final member in switchStatement.members) {
        final name = _switchMemberCaseName(member);
        final value = _findReturnedExpression(member.statements);
        if (name != null && value != null) rows.add((name, value));
      }
    }
  }
  if (rows.isEmpty) {
    issues.add(
      ValidationIssue(
        severity: ValidationSeverity.error,
        code: 'actor_catalog_shape',
        message: 'Cannot resolve $catalogClass.get archetypes.',
        sourcePath: sourcePath,
      ),
    );
  }
  final entries = <EntityEntry>[];
  final importedRenderResolvers = <String, _ConstValueResolver?>{};
  for (final (actorName, expression) in rows) {
    final resolved = resolver._resolveExpression(expression, <String>{});
    final NodeList<Argument>? args = resolved is InstanceCreationExpression
        ? resolved.argumentList.arguments
        : resolved is MethodInvocation
        ? resolved.argumentList.arguments
        : null;
    if (args == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'actor_archetype_shape',
          message: 'Cannot resolve $actorName catalog source.',
          sourcePath: sourcePath,
        ),
      );
      continue;
    }
    final colliderExpr = _namedArgumentExpression(args, 'collider');
    final resolvedCollider = _resolveColliderAabbExpression(unit, colliderExpr);
    if (resolvedCollider == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.warning,
          code: 'enemy_collider_missing',
          message: 'Enemy $actorName has no writable ColliderAabbDef collider.',
          sourcePath: sourcePath,
        ),
      );
      continue;
    }
    final colliderArgs = resolvedCollider.arguments;

    final halfXArg = _namedArgument(colliderArgs, 'halfX');
    final halfYArg = _namedArgument(colliderArgs, 'halfY');
    final offsetXArg = _namedArgument(colliderArgs, 'offsetX');
    final offsetYArg = _namedArgument(colliderArgs, 'offsetY');
    final halfX = halfXArg == null
        ? null
        : _doubleFromExpression(halfXArg.argumentExpression);
    final halfY = halfYArg == null
        ? null
        : _doubleFromExpression(halfYArg.argumentExpression);
    if (halfX == null ||
        halfY == null ||
        halfXArg == null ||
        halfYArg == null) {
      issues.add(
        ValidationIssue(
          severity: ValidationSeverity.error,
          code: 'enemy_half_extents_missing',
          message:
              'Enemy $actorName collider is missing halfX/halfY numeric values.',
          sourcePath: sourcePath,
        ),
      );
      continue;
    }
    final offsetX = offsetXArg == null
        ? 0.0
        : _doubleFromExpression(offsetXArg.argumentExpression) ?? 0.0;
    final offsetY = offsetYArg == null
        ? 0.0
        : _doubleFromExpression(offsetYArg.argumentExpression) ?? 0.0;
    final artFacingDirection =
        _facingFromExpression(_namedArgumentExpression(args, 'artFacingDir')) ??
        defaultFacing;
    final castOriginOffsetArg = _namedArgument(args, 'castOriginOffset');
    final castOriginOffset = castOriginOffsetArg == null
        ? null
        : _doubleFromExpression(castOriginOffsetArg.argumentExpression);
    final launchHeight = _namedArgumentExpression(args, 'castOriginOffsetY');
    final castOriginOffsetBinding = _scalarBindingFromNamedArg(
      sourcePath: sourcePath,
      source: source,
      kind: EntitySourceBindingKind.castOriginOffsetScalar,
      namedArg: castOriginOffsetArg,
    );
    final isCaster =
        _hasNonNullNamedArgument(args, 'primaryCastAbilityId') ||
        castOriginOffset != null;

    final colliderBindings = EntityColliderSourceBindings(
      halfX: _requiredColliderScalarBinding(
        sourcePath: sourcePath,
        source: source,
        namedArg: halfXArg,
      ),
      halfY: _requiredColliderScalarBinding(
        sourcePath: sourcePath,
        source: source,
        namedArg: halfYArg,
      ),
      offsetX: _colliderScalarBindingFromNamedArg(
        sourcePath: sourcePath,
        source: source,
        namedArg: offsetXArg,
      ),
      offsetY: _colliderScalarBindingFromNamedArg(
        sourcePath: sourcePath,
        source: source,
        namedArg: offsetYArg,
      ),
    );
    final renderAnimExpression = _namedArgumentExpression(args, 'renderAnim');
    final parsedReferenceVisual = renderAnimExpression == null
        ? null
        : resolver.resolveRenderVisual(renderAnimExpression) ??
              _resolveImportedActorRenderVisual(
                workspace,
                unit,
                sourcePath,
                renderAnimExpression,
                importedRenderResolvers,
              );
    final renderScaleArg = _namedArgument(args, 'renderScale');
    final renderScaleValue = renderScaleArg == null
        ? null
        : _doubleFromExpression(renderScaleArg.argumentExpression);
    final renderScaleBinding = _scalarBindingFromNamedArg(
      sourcePath: sourcePath,
      source: source,
      kind: EntitySourceBindingKind.referenceRenderScaleScalar,
      namedArg: renderScaleArg,
    );
    final referenceVisual = _withRenderScale(
      parsedReferenceVisual,
      renderScaleValue == null || renderScaleBinding == null
          ? null
          : _ResolvedScalarValue(
              value: renderScaleValue,
              binding: renderScaleBinding,
            ),
    );
    entries.add(
      EntityEntry(
        id: '${entityType.name}.$actorName',
        label:
            '${entityType == EntityType.npc ? 'NPC' : 'Enemy'}: ${_titleCaseCamel(actorName)}',
        entityType: entityType,
        halfX: halfX,
        halfY: halfY,
        offsetX: offsetX,
        offsetY: offsetY,
        sourcePath: sourcePath,
        colliderBindings: colliderBindings,
        referenceVisual: referenceVisual,
        artFacingDirection: artFacingDirection,
        isCaster: isCaster,
        castOriginOffset: castOriginOffset,
        castOriginOffsetY: launchHeight == null
            ? 0
            : _doubleFromExpression(launchHeight) ?? double.nan,
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
        NodeList<Argument>? args;
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

        final width = _doubleFromExpression(widthArg.argumentExpression);
        final height = _doubleFromExpression(heightArg.argumentExpression);
        final offsetX = _doubleFromExpression(offsetXArg.argumentExpression);
        final offsetY = _doubleFromExpression(offsetYArg.argumentExpression);
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
            : _doubleFromExpression(castOriginOffsetArg.argumentExpression);
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
        final colliderBindings = EntityColliderSourceBindings(
          halfX: _requiredColliderScalarBinding(
            sourcePath: relativePath,
            source: source,
            namedArg: widthArg,
            sourceUnitsPerEditorUnit: 2.0,
          ),
          halfY: _requiredColliderScalarBinding(
            sourcePath: relativePath,
            source: source,
            namedArg: heightArg,
            sourceUnitsPerEditorUnit: 2.0,
          ),
          offsetX: _requiredColliderScalarBinding(
            sourcePath: relativePath,
            source: source,
            namedArg: offsetXArg,
          ),
          offsetY: _requiredColliderScalarBinding(
            sourcePath: relativePath,
            source: source,
            namedArg: offsetYArg,
          ),
        );
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
            colliderBindings: colliderBindings,
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
        message: 'ProjectileCatalog.get(ProjectileId) does not contain a switch block.',
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

    final sizeX = _doubleFromExpression(sizeXArg.argumentExpression);
    final sizeY = _doubleFromExpression(sizeYArg.argumentExpression);
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

    final colliderBindings = EntityColliderSourceBindings(
      halfX: _requiredColliderScalarBinding(
        sourcePath: EntitySourceParser.projectileCatalogPath,
        source: source,
        namedArg: sizeXArg,
        sourceUnitsPerEditorUnit: 2.0,
      ),
      halfY: _requiredColliderScalarBinding(
        sourcePath: EntitySourceParser.projectileCatalogPath,
        source: source,
        namedArg: sizeYArg,
        sourceUnitsPerEditorUnit: 2.0,
      ),
    );
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
        colliderBindings: colliderBindings,
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
        message: 'Could not locate ProjectileRenderCatalog.get(ProjectileId) method.',
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
  final projectileById = _parseRegistryRenderScales(
    workspace,
    sourcePath: EntitySourceParser.projectileRenderRegistryPath,
    idPrefix: 'ProjectileId',
    entryCtorName: 'ProjectileRenderEntry',
  );
  return _RenderScaleConfig(
    playerScale: playerScale,
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
  final match = RegExp(r'this\.scale\s*=\s*(-?[0-9]+(?:\.[0-9]+)?)')
      .firstMatch(source);
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
