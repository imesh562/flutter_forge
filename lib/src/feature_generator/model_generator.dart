import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

final class ModelGenerator {
  Future<void> generateRequest({
    required String projectPath,
    required String pkg,
    required String feature,
    required String endpointName,
    required List<Map<String, String>> fields,
    List<NestedClassDef> nestedClasses = const [],
    bool forceOverwrite = false,
  }) async {
    final className = '${StringUtils.toPascalCase(endpointName)}Request';
    final fileName = '${StringUtils.toSnakeCase(endpointName)}_request.dart';
    final filePath = p.join(
      projectPath,
      'lib/features/$feature/data/models/$fileName',
    );

    _guardFileAbsent(filePath, forceOverwrite: forceOverwrite);

    final modelsDir = p.join(projectPath, 'lib/features/$feature/data/models');
    final existing = await _scanExistingClasses(modelsDir, filePath);
    final (toEmit, importFiles) = _partitionNested(nestedClasses, existing);

    final fieldDeclarations = fields.map(_fieldDecl).join('\n');
    final constructorParams = fields
        .map((f) => '    this.${f['name']},')
        .join('\n');
    final partName = '${StringUtils.toSnakeCase(endpointName)}_request.g.dart';
    final nestedBlocks = toEmit.map(_nestedRequestClass).join('\n');
    final extraImports = _buildImportBlock(importFiles);

    await FileUtils.writeFile(
      filePath,
      '''
import 'package:json_annotation/json_annotation.dart';
$extraImports
part '$partName';

@JsonSerializable(explicitToJson: true)
final class $className {
  const $className({
$constructorParams
  });

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);

$fieldDeclarations

  Map<String, dynamic> toJson() => _\$${className}ToJson(this);
}
${nestedBlocks.isNotEmpty ? '\n$nestedBlocks\n' : ''}''',
    );
  }

  Future<void> generateResponse({
    required String projectPath,
    required String pkg,
    required String feature,
    required String endpointName,
    required List<Map<String, String>> fields,
    List<NestedClassDef> nestedClasses = const [],
    bool forceOverwrite = false,
  }) async {
    final className = '${StringUtils.toPascalCase(endpointName)}Response';
    final fileName = '${StringUtils.toSnakeCase(endpointName)}_response.dart';
    final filePath = p.join(
      projectPath,
      'lib/features/$feature/data/models/$fileName',
    );

    _guardFileAbsent(filePath, forceOverwrite: forceOverwrite);

    final modelsDir = p.join(projectPath, 'lib/features/$feature/data/models');
    final existing = await _scanExistingClasses(modelsDir, filePath);
    final (toEmit, importFiles) = _partitionNested(nestedClasses, existing);

    final fieldDeclarations = fields.map(_fieldDecl).join('\n');
    final constructorParams = fields
        .map((f) => '    this.${f['name']},')
        .join('\n');
    final propsItems = fields.map((f) => f['name']).join(', ');
    final partName = '${StringUtils.toSnakeCase(endpointName)}_response.g.dart';
    final nestedBlocks = toEmit.map(_nestedResponseClass).join('\n');
    final extraImports = _buildImportBlock(importFiles);

    await FileUtils.writeFile(
      filePath,
      '''
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
$extraImports
part '$partName';

@JsonSerializable()
final class $className extends Equatable {
  const $className({
$constructorParams
  });

  factory $className.fromJson(Map<String, dynamic> json) =>
      _\$${className}FromJson(json);

$fieldDeclarations

  @override
  List<Object?> get props => [$propsItems];
}
${nestedBlocks.isNotEmpty ? '\n$nestedBlocks\n' : ''}''',
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _nestedRequestClass(NestedClassDef n) {
    final fieldDeclarations = n.fields.map(_fieldDecl).join('\n');
    final constructorParams =
        n.fields.map((f) => '    this.${f['name']},').join('\n');
    return '''
@JsonSerializable(explicitToJson: true)
final class ${n.className} {
  const ${n.className}({
$constructorParams
  });

  factory ${n.className}.fromJson(Map<String, dynamic> json) =>
      _\$${n.className}FromJson(json);

$fieldDeclarations

  Map<String, dynamic> toJson() => _\$${n.className}ToJson(this);
}''';
  }

  String _nestedResponseClass(NestedClassDef n) {
    final fieldDeclarations = n.fields.map(_fieldDecl).join('\n');
    final constructorParams =
        n.fields.map((f) => '    this.${f['name']},').join('\n');
    final propsItems = n.fields.map((f) => f['name']).join(', ');
    return '''
@JsonSerializable()
final class ${n.className} extends Equatable {
  const ${n.className}({
$constructorParams
  });

  factory ${n.className}.fromJson(Map<String, dynamic> json) =>
      _\$${n.className}FromJson(json);

$fieldDeclarations

  @override
  List<Object?> get props => [$propsItems];
}''';
  }

  /// Emits a single nullable field declaration, prefixed with
  /// `@JsonKey(name: '...')` when the JSON key differs from the Dart name.
  String _fieldDecl(Map<String, String> f) {
    final jsonKey = f['jsonKey'];
    final annotation =
        jsonKey != null ? "  @JsonKey(name: '$jsonKey')\n" : '';
    return '${annotation}  final ${f['type']}? ${f['name']};';
  }

  /// Splits [nestedClasses] into classes to emit inline and files to import.
  ///
  /// A nested class is reused (imported) only when an existing file defines a
  /// class with the **same name AND the same set of field names**. If the names
  /// match but the fields differ, the class is emitted inline so the developer
  /// sees both definitions and can resolve the conflict.
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

  /// Scans [modelsDir] for `final class` declarations, returning
  /// `{ClassName: (fileName, fieldNames)}`.
  /// Skips [excludeFilePath] and generated `.g.dart` files.
  Future<Map<String, ({String fileName, Set<String> fieldNames})>>
      _scanExistingClasses(
    String modelsDir,
    String excludeFilePath,
  ) async {
    final result = <String, ({String fileName, Set<String> fieldNames})>{};
    final dir = Directory(modelsDir);
    if (!dir.existsSync()) return result;

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
      if (p.canonicalize(path) == p.canonicalize(excludeFilePath)) continue;

      final source = await entity.readAsString();
      final fileName = p.basename(path);
      for (final cls in JsonTypeInferrer.parseAllClassesFromSource(source)) {
        final fieldNames = cls.fields.map((f) => f['name']!).toSet();
        // First file found wins; don't overwrite earlier entries.
        result.putIfAbsent(
          cls.className,
          () => (fileName: fileName, fieldNames: fieldNames),
        );
      }
    }
    return result;
  }

  /// Builds a '\n'-prefixed import block for [files], or empty string if none.
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
      throw StateError(
        'Model file already exists: $filePath\n'
        'Use "Update request / response model" in the wizard to modify it.',
      );
    }
  }
}
