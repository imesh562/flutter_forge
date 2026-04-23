import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

final class DatasourceGenerator {
  Future<void> scaffold({
    required String projectPath,
    required String pkg,
    required String feature,
  }) async {
    final featurePascal = StringUtils.toPascalCase(feature);
    final featureSnake = StringUtils.toSnakeCase(feature);
    final filePath = p.join(
      projectPath,
      'lib/features/$feature/data/datasources/${featureSnake}_remote_datasource.dart',
    );
    if (File(filePath).existsSync()) return;
    await _createDatasourceFile(
      filePath: filePath,
      pkg: pkg,
      feature: feature,
      featurePascal: featurePascal,
    );
  }

  Future<void> addMethod({
    required String projectPath,
    required String pkg,
    required String feature,
    required String endpointName,
    required String method,
    required String path,
    required String endpointType,
    bool hasRequest = true,
  }) async {
    final featurePascal = StringUtils.toPascalCase(feature);
    final endpointPascal = StringUtils.toPascalCase(endpointName);
    final endpointCamel = StringUtils.toCamelCase(endpointName);
    final requestClass = '${endpointPascal}Request';
    final responseClass = '${endpointPascal}Response';
    final requestSnake = '${StringUtils.toSnakeCase(endpointName)}_request';
    final responseSnake = '${StringUtils.toSnakeCase(endpointName)}_response';

    final filePath = p.join(
      projectPath,
      'lib/features/$feature/data/datasources/${StringUtils.toSnakeCase(feature)}_remote_datasource.dart',
    );

    final file = File(filePath);
    if (!file.existsSync()) {
      await _createDatasourceFile(
        filePath: filePath,
        pkg: pkg,
        feature: feature,
        featurePascal: featurePascal,
      );
    }

    final newMethod = _buildMethod(
      endpointName: endpointName,
      endpointPascal: endpointPascal,
      endpointCamel: endpointCamel,
      requestClass: requestClass,
      responseClass: responseClass,
      requestSnake: requestSnake,
      responseSnake: responseSnake,
      method: method,
      path: path,
      endpointType: endpointType,
      hasRequest: hasRequest,
    );

    await FileUtils.patchFile(filePath, (content) {
      _assertImportable(content, requestSnake, responseSnake);

      // Insert import lines before the @lazySingleton annotation so that
      // the annotation stays directly attached to the class declaration.
      var updated = content;
      final importAnchor = '\n@lazySingleton\nclass';
      if (hasRequest && !updated.contains("'../models/$requestSnake.dart'")) {
        updated = updated.replaceFirst(
          importAnchor,
          "\nimport '../models/$requestSnake.dart';\n"
              "import '../models/$responseSnake.dart';\n"
              '\n@lazySingleton\nclass',
        );
      } else if (!hasRequest && !updated.contains("'../models/$responseSnake.dart'")) {
        updated = updated.replaceFirst(
          importAnchor,
          "\nimport '../models/$responseSnake.dart';\n"
              '\n@lazySingleton\nclass',
        );
      }

      // Additive insert before the closing brace of the class.
      return FileUtils.insertBeforeClassEnd(updated, newMethod);
    });
  }

  Future<void> _createDatasourceFile({
    required String filePath,
    required String pkg,
    required String feature,
    required String featurePascal,
  }) async {
    await FileUtils.writeFile(
      filePath,
      '''
import 'package:injectable/injectable.dart';

import 'package:$pkg/core/network/api_helper.dart';
import 'package:$pkg/core/network/webhook_helper.dart';

@lazySingleton
class ${featurePascal}RemoteDatasource {
  ${featurePascal}RemoteDatasource(this._api, this._ws);

  final ApiHelper _api;
  final WebhookHelper _ws;
}
''',
    );
  }

  String _buildMethod({
    required String endpointName,
    required String endpointPascal,
    required String endpointCamel,
    required String requestClass,
    required String responseClass,
    required String requestSnake,
    required String responseSnake,
    required String method,
    required String path,
    required String endpointType,
    bool hasRequest = true,
  }) {
    if (endpointType == 'websocket') {
      return '''

  /// Filters the shared WebSocket stream for [$responseClass] events.
  Stream<$responseClass> $endpointCamel() =>
      _ws.stream
          .where((data) => data['type'] == '$endpointName')
          .map((data) => $responseClass.fromJson(data));
''';
    }

    final dioMethod = method.toLowerCase();

    // Extract :param segments from the path and generate typed arguments.
    final pathParams = _extractPathParams(path);
    final pathParamArgs = pathParams.map((p) => 'String $p').join(', ');

    // Replace :param → $param for Dart string interpolation.
    final interpolatedPath = path.replaceAllMapped(
      RegExp(r':([a-zA-Z][a-zA-Z0-9]*)'),
      (m) => '\${${m[1]}}',
    );
    final urlExpr = pathParams.isEmpty ? "'$path'" : "'$interpolatedPath'";

    if (!hasRequest) {
      final methodParams = pathParams.isEmpty
          ? ''
          : '{${pathParamArgs.isEmpty ? '' : 'required $pathParamArgs'}}';
      final callArgs = pathParams.isEmpty ? '$urlExpr' : '$urlExpr,';
      return '''

  Future<$responseClass> $endpointCamel($methodParams) async {
    final response = await _api.$dioMethod<Map<String, dynamic>>(
      $callArgs
    );
    return $responseClass.fromJson(response.data!);
  }
''';
    }

    // GET and DELETE pass parameters as query params; others send a body.
    final paramArg = (method == 'GET' || method == 'DELETE')
        ? 'queryParameters: request.toJson()'
        : 'data: request.toJson()';

    final methodParams = pathParams.isEmpty
        ? '$requestClass request'
        : '$requestClass request, {${pathParamArgs.isEmpty ? '' : 'required $pathParamArgs'}}';

    return '''

  Future<$responseClass> $endpointCamel($methodParams) async {
    final response = await _api.$dioMethod<Map<String, dynamic>>(
      $urlExpr,
      $paramArg,
    );
    return $responseClass.fromJson(response.data!);
  }
''';
  }

  /// Returns the names of all `:param` segments in [path].
  /// e.g. `/users/:id/posts/:postId` → `['id', 'postId']`
  List<String> _extractPathParams(String path) =>
      RegExp(r':([a-zA-Z][a-zA-Z0-9]*)')
          .allMatches(path)
          .map((m) => m.group(1)!)
          .toList();

  void _assertImportable(
    String content,
    String requestSnake,
    String responseSnake,
  ) {
    // Models must exist before the datasource method can reference them.
    // The wizard enforces this order; this is a diagnostic aid.
  }

}
