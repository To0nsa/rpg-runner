// Shared source, AST, and binding helpers for the entities parser.
//
// Domain loaders call into this file for common source reading, lightweight AST
// queries, id normalization, and source-binding capture so their control flow
// stays focused on runtime contracts rather than parser plumbing.
part of '../entity_source_parser.dart';

// Optional auxiliary sources should not fail the whole load; callers decide
// whether absence is acceptable for the specific metadata they are resolving.
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

MethodDeclaration? _findProjectileRenderCatalogGetMethod(CompilationUnit unit) {
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

InstanceCreationExpression? _findReturnedInstance(List<Statement> statements) {
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

EntitySourceBinding? _bindingFromNodes({
  required String sourcePath,
  required String source,
  required EntitySourceBindingKind kind,
  required Iterable<AstNode> nodes,
}) {
  // Bind from the concrete AST nodes we found rather than assuming those named
  // arguments appear in a fixed textual order inside the source file.
  var hasNode = false;
  var start = source.length;
  var end = -1;
  for (final node in nodes) {
    hasNode = true;
    if (node.offset < start) {
      start = node.offset;
    }
    if (node.end > end) {
      end = node.end;
    }
  }
  if (!hasNode || start < 0 || end <= start || end > source.length) {
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
