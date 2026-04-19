import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

final class ModelGenerator {
  Future<void> generateRequest({
    required String projectPath,
    required String pkg,
    required String feature,
    required String endpointName,
    required List<Map<String, String>> fields,
    bool forceOverwrite = false,
  }) async {
    final className = '${StringUtils.toPascalCase(endpointName)}Request';
    final fileName = '${StringUtils.toSnakeCase(endpointName)}_request.dart';
    final filePath = p.join(
      projectPath,
      'lib/features/$feature/data/models/$fileName',
    );

    _guardFileAbsent(filePath, forceOverwrite: forceOverwrite);

    final fieldDeclarations = fields
        .map((f) => '  final ${f['type']} ${f['name']};')
        .join('\n');
    final constructorParams = fields
        .map((f) => '    required this.${f['name']},')
        .join('\n');
    final partName = '${StringUtils.toSnakeCase(endpointName)}_request.g.dart';

    await FileUtils.writeFile(
      filePath,
      '''
import 'package:json_annotation/json_annotation.dart';

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
''',
    );
  }

  Future<void> generateResponse({
    required String projectPath,
    required String pkg,
    required String feature,
    required String endpointName,
    required List<Map<String, String>> fields,
    bool forceOverwrite = false,
  }) async {
    final className = '${StringUtils.toPascalCase(endpointName)}Response';
    final fileName = '${StringUtils.toSnakeCase(endpointName)}_response.dart';
    final filePath = p.join(
      projectPath,
      'lib/features/$feature/data/models/$fileName',
    );

    _guardFileAbsent(filePath, forceOverwrite: forceOverwrite);

    // Response fields are nullable for forward compatibility.
    final fieldDeclarations = fields
        .map((f) => '  final ${f['type']}? ${f['name']};')
        .join('\n');
    final constructorParams = fields
        .map((f) => '    this.${f['name']},')
        .join('\n');
    final propsItems = fields.map((f) => f['name']).join(', ');
    final partName = '${StringUtils.toSnakeCase(endpointName)}_response.g.dart';

    await FileUtils.writeFile(
      filePath,
      '''
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

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
''',
    );
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
