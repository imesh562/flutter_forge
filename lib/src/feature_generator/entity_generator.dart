import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

/// Generates a pure domain entity class under
/// `lib/features/<feature>/domain/entities/`.
///
/// Entities extend [Equatable] and carry nullable fields but have no
/// JSON annotations — serialization is the responsibility of the data layer.
final class EntityGenerator {
  Future<void> generate({
    required String projectPath,
    required String pkg,
    required String feature,
    required String entityName,
    required List<Map<String, String>> fields,
    List<NestedClassDef> nestedClasses = const [],
    bool forceOverwrite = false,
  }) async {
    final className = StringUtils.toPascalCase(entityName);
    final fileName = '${StringUtils.toSnakeCase(entityName)}.dart';
    final filePath = p.join(
      projectPath,
      'lib/features/$feature/domain/entities/$fileName',
    );

    _guardFileAbsent(filePath, forceOverwrite: forceOverwrite);

    final entitiesDir =
        p.join(projectPath, 'lib/features/$feature/domain/entities');
    final existing = await _scanExistingClasses(entitiesDir, filePath);
    final (toEmit, importFiles) = _partitionNested(nestedClasses, existing);

    final fieldDeclarations = fields.map(_fieldDecl).join('\n');
    final constructorParams =
        fields.map((f) => '    this.${f['name']},').join('\n');
    final propsItems = fields.map((f) => f['name']).join(', ');
    final nestedBlocks = toEmit.map(_nestedClass).join('\n');
    final extraImports = _buildImportBlock(importFiles);

    await FileUtils.writeFile(
      filePath,
      '''
import 'package:equatable/equatable.dart';
$extraImports
final class $className extends Equatable {
  const $className({
$constructorParams
  });

$fieldDeclarations

  @override
  List<Object?> get props => [$propsItems];
}
${nestedBlocks.isNotEmpty ? '\n$nestedBlocks\n' : ''}''',
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _nestedClass(NestedClassDef n) {
    final fieldDeclarations = n.fields.map(_fieldDecl).join('\n');
    final constructorParams =
        n.fields.map((f) => '    this.${f['name']},').join('\n');
    final propsItems = n.fields.map((f) => f['name']).join(', ');
    return '''
final class ${n.className} extends Equatable {
  const ${n.className}({
$constructorParams
  });

$fieldDeclarations

  @override
  List<Object?> get props => [$propsItems];
}''';
  }

  /// Entities are pure Dart — no @JsonKey, just the field declaration.
  String _fieldDecl(Map<String, String> f) =>
      '  final ${f['type']}? ${f['name']};';

  (List<NestedClassDef>, Set<String>) _partitionNested(
    List<NestedClassDef> nestedClasses,
    Map<String, ({String fileName, Set<String> fieldNames})> existingClasses,
  ) {
    final toEmit = <NestedClassDef>[];
    final importFiles = <String>{};
    for (final n in nestedClasses) {
      final info = existingClasses[n.className];
      if (info != null && _fieldNamesMatch(n.fields, info.fieldNames)) {
        importFiles.add(info.fileName);
      } else {
        toEmit.add(n);
      }
    }
    return (toEmit, importFiles);
  }

  bool _fieldNamesMatch(
    List<Map<String, String>> fields,
    Set<String> existingFieldNames,
  ) {
    final incoming = fields.map((f) => f['name']!).toSet();
    return incoming.length == existingFieldNames.length &&
        incoming.every(existingFieldNames.contains);
  }

  Future<Map<String, ({String fileName, Set<String> fieldNames})>>
      _scanExistingClasses(
    String entitiesDir,
    String excludeFilePath,
  ) async {
    final result = <String, ({String fileName, Set<String> fieldNames})>{};
    final dir = Directory(entitiesDir);
    if (!dir.existsSync()) return result;

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart')) continue;
      if (p.canonicalize(path) == p.canonicalize(excludeFilePath)) continue;

      final source = await entity.readAsString();
      final fileName = p.basename(path);
      for (final cls in JsonTypeInferrer.parseAllClassesFromSource(source)) {
        final fieldNames = cls.fields.map((f) => f['name']!).toSet();
        result.putIfAbsent(
          cls.className,
          () => (fileName: fileName, fieldNames: fieldNames),
        );
      }
    }
    return result;
  }

  String _buildImportBlock(Set<String> files) {
    if (files.isEmpty) return '';
    final sorted = files.toList()..sort();
    return '\n${sorted.map((f) => "import '$f';").join('\n')}';
  }

  void _guardFileAbsent(String filePath, {bool forceOverwrite = false}) {
    if (!filePath.endsWith('.dart')) {
      throw StateError('Invalid file path (expected .dart): $filePath');
    }
    if (!forceOverwrite && File(filePath).existsSync()) {
      throw StateError('Entity file already exists: $filePath');
    }
  }
}
