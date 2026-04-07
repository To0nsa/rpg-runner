// Const and expression resolution for entity preview metadata.
//
// The entities editor needs more than literal parsing: render visuals often go
// through top-level const indirection and simple expressions. This file resolves
// just the supported subset needed for preview plus deterministic rewrite
// bindings, without turning the parser into a full Dart evaluator.
part of '../entity_source_parser.dart';

/// Resolves supported const-backed render metadata within one source file.
///
/// The resolver intentionally understands only the expression shapes the
/// entities workflow can later round-trip safely.
class _ConstValueResolver {
  _ConstValueResolver({
    required CompilationUnit unit,
    required String sourcePath,
    required String sourceContent,
  }) : _sourcePath = sourcePath,
       _sourceContent = sourceContent,
       _initializerByName = _collectConstInitializers(unit);

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

    final frameWidthExpr = _namedArgumentExpression(arguments, 'frameWidth');
    final frameHeightExpr = _namedArgumentExpression(arguments, 'frameHeight');
    final frameWidth = frameWidthExpr == null
        ? null
        : _resolveDouble(frameWidthExpr);
    final frameHeight = frameHeightExpr == null
        ? null
        : _resolveDouble(frameHeightExpr);
    final anchorPointExpr = _namedArgumentExpression(arguments, 'anchorPoint');
    final anchorPoint = _resolveVec2(anchorPointExpr);
    final anchorArgs = _vec2Arguments(anchorPointExpr);
    final anchorBinding = _resolveExpressionBinding(
      anchorPointExpr,
      EntitySourceBindingKind.referenceAnchorVec2Expression,
    );
    final anchorXWriteBinding = anchorArgs == null
        ? null
        : _resolveExpressionRewriteBinding(anchorArgs[0]);
    final anchorYWriteBinding = anchorArgs == null
        ? null
        : _resolveExpressionRewriteBinding(anchorArgs[1]);

    final sourcesExpr = _namedArgumentExpression(arguments, 'sourcesByKey');
    final sourceByAnimKey = sourcesExpr == null
        ? const <String, String>{}
        : _resolveAnimSourceMap(sourcesExpr);
    final rowByAnimKey = _resolveAnimIntMap(
      _namedArgumentExpression(arguments, 'rowByKey'),
    );
    final frameStartByAnimKey = _resolveAnimIntMap(
      _namedArgumentExpression(arguments, 'frameStartByKey'),
    );
    final frameCountByAnimKey = _resolveAnimIntMap(
      _namedArgumentExpression(arguments, 'frameCountsByKey'),
    );
    final gridColumnsByAnimKey = _resolveAnimIntMap(
      _namedArgumentExpression(arguments, 'gridColumnsByKey'),
    );

    final animViewsByKey = <String, EntityReferenceAnimView>{};
    for (final entry in sourceByAnimKey.entries) {
      final key = entry.key;
      final assetPath = entry.value;
      if (assetPath.isEmpty) {
        continue;
      }
      animViewsByKey[key] = EntityReferenceAnimView(
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
      anchorXWriteBinding: anchorXWriteBinding,
      anchorYWriteBinding: anchorYWriteBinding,
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

  EntityExpressionRewriteBinding? _resolveExpressionRewriteBinding(
    Expression expression,
  ) {
    final resolved = _resolveExpression(expression, <String>{});
    if (resolved is ParenthesizedExpression) {
      return _resolveExpressionRewriteBinding(resolved.expression);
    }

    final expressionBinding = _resolveExpressionBinding(
      resolved,
      EntitySourceBindingKind.referenceAnchorVec2Expression,
    );
    if (expressionBinding == null) {
      return null;
    }

    final literalValue = _doubleFromExpression(resolved);
    if (literalValue != null) {
      return EntityExpressionRewriteBinding(
        mode: EntityExpressionRewriteMode.replaceExpression,
        expressionBinding: expressionBinding,
      );
    }

    if (resolved is! BinaryExpression) {
      return null;
    }

    final left = resolved.leftOperand;
    final right = resolved.rightOperand;
    final leftLiteral = _doubleFromExpression(left);
    final rightLiteral = _doubleFromExpression(right);
    final leftValue = _resolveDouble(left);
    final rightValue = _resolveDouble(right);

    // Only keep expression-preserving rewrite modes for simple scalar forms the
    // exporter can invert deterministically.
    switch (resolved.operator.lexeme) {
      case '*':
        if (leftLiteral != null &&
            rightLiteral == null &&
            rightValue != null &&
            rightValue.isFinite &&
            rightValue.abs() > 0.000001) {
          final scalarBinding = _resolveExpressionBinding(
            left,
            EntitySourceBindingKind.referenceAnchorVec2Expression,
          );
          if (scalarBinding != null) {
            return EntityExpressionRewriteBinding(
              mode: EntityExpressionRewriteMode.multiplyByScalar,
              expressionBinding: expressionBinding,
              scalarBinding: scalarBinding,
              basisValue: rightValue,
            );
          }
        }
        if (rightLiteral != null &&
            leftLiteral == null &&
            leftValue != null &&
            leftValue.isFinite &&
            leftValue.abs() > 0.000001) {
          final scalarBinding = _resolveExpressionBinding(
            right,
            EntitySourceBindingKind.referenceAnchorVec2Expression,
          );
          if (scalarBinding != null) {
            return EntityExpressionRewriteBinding(
              mode: EntityExpressionRewriteMode.multiplyByScalar,
              expressionBinding: expressionBinding,
              scalarBinding: scalarBinding,
              basisValue: leftValue,
            );
          }
        }
      case '/':
        if (rightLiteral != null &&
            leftValue != null &&
            leftValue.isFinite &&
            leftValue.abs() > 0.000001) {
          final scalarBinding = _resolveExpressionBinding(
            right,
            EntitySourceBindingKind.referenceAnchorVec2Expression,
          );
          if (scalarBinding != null) {
            return EntityExpressionRewriteBinding(
              mode: EntityExpressionRewriteMode.divideByScalar,
              expressionBinding: expressionBinding,
              scalarBinding: scalarBinding,
              basisValue: leftValue,
            );
          }
        }
        if (leftLiteral != null &&
            rightValue != null &&
            rightValue.isFinite &&
            rightValue.abs() > 0.000001) {
          final scalarBinding = _resolveExpressionBinding(
            left,
            EntitySourceBindingKind.referenceAnchorVec2Expression,
          );
          if (scalarBinding != null) {
            return EntityExpressionRewriteBinding(
              mode: EntityExpressionRewriteMode.scalarDividedByValue,
              expressionBinding: expressionBinding,
              scalarBinding: scalarBinding,
              basisValue: rightValue,
            );
          }
        }
    }

    return null;
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
    final literalValue = _doubleFromExpression(resolved);
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
    final args = _vec2Arguments(expression);
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

  NodeList<Expression>? _vec2Arguments(Expression? expression) {
    if (expression == null) {
      return null;
    }
    final resolved = _resolveExpression(expression, <String>{});
    if (resolved is InstanceCreationExpression &&
        resolved.constructorName.type.toSource() == 'Vec2') {
      return resolved.argumentList.arguments;
    }
    if (resolved is MethodInvocation && resolved.methodName.name == 'Vec2') {
      return resolved.argumentList.arguments;
    }
    return null;
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
      final keyName = _enumCaseName(element.key);
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
      final keyName = _enumCaseName(element.key);
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

/// One resolved numeric value plus the exact source slice that produced it.
class _ResolvedScalarValue {
  const _ResolvedScalarValue({required this.value, required this.binding});

  final double value;
  final EntitySourceBinding binding;
}
