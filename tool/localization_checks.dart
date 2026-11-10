import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Validates translator context and exact key/placeholder parity before generation.
List<String> checkResources(
  Map<String, dynamic> english,
  Map<String, dynamic> translated,
) {
  final errors = <String>[];
  final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
  final other = translated.keys.where((key) => !key.startsWith('@')).toSet();
  for (final key in keys.difference(other)) {
    errors.add('Missing message: $key');
  }
  for (final key in other.difference(keys)) {
    errors.add('Unknown message: $key');
  }
  for (final key in keys.intersection(other)) {
    for (final resource in [english, translated]) {
      final text = resource[key];
      final metadata = resource['@$key'] ?? english['@$key'];
      if (text is! String || text.trim().isEmpty) {
        errors.add('Empty/non-string message: $key');
        continue;
      }
      final sourceMetadata = english['@$key'] as Map?;
      final context = metadata is Map
          ? (metadata['description'] ?? sourceMetadata?['description'])
          : null;
      if (metadata is! Map || context is! String || context.trim().isEmpty) {
        errors.add('Missing translator context: $key');
        continue;
      }
      try {
        final actual = messagePlaceholders(text);
        final declared = (metadata['placeholders'] as Map? ?? {}).keys.toSet();
        if (actual.length != declared.length || !actual.containsAll(declared)) {
          errors.add('Placeholder declarations differ from text: $key');
        }
      } on FormatException {
        errors.add('Invalid message syntax: $key');
      }
    }
    final a = english['@$key'];
    final b = translated['@$key'];
    if (a is Map &&
        b is Map &&
        _canonical(a['placeholders'] ?? {}) !=
            _canonical(b['placeholders'] ?? {})) {
      errors.add('Placeholder types/format/context differ: $key');
    }
  }
  return errors;
}

String _canonical(Object? value) => jsonEncode(_sort(value));
Object? _sort(Object? value) => value is Map
    ? {
        for (final key in value.keys.cast<String>().toList()..sort())
          key: _sort(value[key]),
      }
    : value is List
    ? value.map(_sort).toList()
    : value;

/// Walks the message grammar, including nested plural/select branches. The Flutter
/// generator remains the syntax authority; this checks that translations retain arguments.
Set<String> messagePlaceholders(String message) {
  final names = <String>{};
  var i = 0;
  void sequence({bool nested = false}) {
    while (i < message.length) {
      if (message[i] == '}') {
        if (!nested) throw const FormatException();
        i++;
        return;
      }
      if (message[i++] != '{') continue;
      final start = i;
      while (i < message.length && message[i] != ',' && message[i] != '}') {
        i++;
      }
      final name = message.substring(start, i).trim();
      if (!RegExp(r'^[a-zA-Z_][a-zA-Z_0-9]*$').hasMatch(name) ||
          i == message.length) {
        throw const FormatException();
      }
      names.add(name);
      if (message[i++] == '}') continue;
      final typeStart = i;
      while (i < message.length && message[i] != ',') {
        i++;
      }
      if (i == message.length ||
          !{
            'plural',
            'select',
            'selectordinal',
          }.contains(message.substring(typeStart, i).trim())) {
        throw const FormatException();
      }
      i++;
      while (i < message.length) {
        while (i < message.length && message[i].trim().isEmpty) {
          i++;
        }
        if (i == message.length) throw const FormatException();
        if (message[i] == '}') {
          i++;
          break;
        }
        while (i < message.length && message[i] != '{') {
          i++;
        }
        if (i++ >= message.length) throw const FormatException();
        sequence(nested: true);
      }
    }
    if (nested) throw const FormatException();
  }

  sequence();
  return names;
}

class TextLiteral {
  const TextLiteral(this.line, this.source);
  final int line;
  final String source;
}

/// Conservative source gate: presentation prose and labels require resources.
/// Technical syntax is recognized by AST context, not a blanket per-file baseline.
List<TextLiteral> hardcodedText(String source, String path) {
  final parsed = parseString(content: source, path: path);
  final found = <TextLiteral>[];
  parsed.unit.accept(
    _TextVisitor((node) {
      if (_technical(node)) return;
      final literal = node is StringInterpolation
          ? node.elements
                .whereType<InterpolationString>()
                .map((part) => part.value)
                .join()
          : node.stringValue ?? '';
      if (!RegExp(r'[a-zA-ZÀ-ž]').hasMatch(literal)) return;
      if (RegExp(r'^(?:assets/|packages/|https?://|package:|dart:|/)[^\s]*$')
              .hasMatch(literal) ||
          RegExp(r'^[\w./-]+\.(?:png|jpg|webp|json)$').hasMatch(literal)) {
        return;
      }
      found.add(
        TextLiteral(
          parsed.lineInfo.getLocation(node.offset).lineNumber,
          node.toSource(),
        ),
      );
    }),
  );
  return found;
}

bool _technical(StringLiteral node) {
  if (node.parent is StringLiteral ||
      node.thisOrAncestorOfType<Directive>() != null) {
    return true;
  }
  for (AstNode? current = node; current != null; current = current.parent) {
    if (current is ThrowExpression ||
        current is AssertInitializer ||
        current is AssertStatement) {
      return true;
    }
    if (current is MapLiteralEntry && identical(current.key, node)) return true;
    if (current is IndexExpression && identical(current.index, node)) {
      return true;
    }
    if (current is BinaryExpression &&
        {'==', '!='}.contains(current.operator.lexeme)) {
      return true;
    }
    if (current is ConstantPattern || current is SwitchCase) return true;
    if (current is NamedArgument &&
        {
          'fontFamily',
          'fontFamilyFallback',
          'debugLabel',
          'fieldName',
          'coalesceKey',
          'commandId',
          'runSessionId',
          'metric',
          'surface',
          'rewardSurface',
          'contentType',
        }.contains(current.name.lexeme)) {
      return true;
    }
    if (current is InstanceCreationExpression) {
      final type = current.constructorName.type.toSource();
      if ({
            'Key',
            'ValueKey',
            'Locale',
            'RegExp',
            'StateError',
            'ArgumentError',
            'FormatException',
            'UnsupportedError',
          }.contains(type.split('<').first) ||
          type.endsWith('Exception') ||
          current.constructorName.name?.name == 'fromEnvironment') {
        return true;
      }
    }
    if (current is MethodInvocation) {
      final name = current.methodName.name;
      final target = current.target?.toSource();
      if ({
            'debugPrint',
            'print',
            'startsWith',
            'endsWith',
            'contains',
            'containsKey',
            'split',
            'lastIndexOf',
            'indexOf',
            'RegExp',
            'Key',
            'ValueKey',
            'Locale',
            'StateError',
            'ArgumentError',
            'FormatException',
            'UnsupportedError',
          }.contains(name) ||
          name.endsWith('Exception') ||
          ({'bool', 'String', 'int'}.contains(target) &&
              name == 'fromEnvironment')) {
        return true;
      }
    }
    if (current is Statement || current is FunctionBody) break;
  }
  return false;
}

class _TextVisitor extends RecursiveAstVisitor<void> {
  _TextVisitor(this.add);
  final void Function(StringLiteral) add;
  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    add(node);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    add(node);
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    add(node);
    super.visitAdjacentStrings(node);
  }
}
