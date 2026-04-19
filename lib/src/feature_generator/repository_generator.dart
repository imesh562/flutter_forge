import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

final class RepositoryGenerator {
  Future<void> scaffold({
    required String projectPath,
    required String pkg,
    required String feature,
  }) async {
    final featurePascal = StringUtils.toPascalCase(feature);
    final featureSnake = StringUtils.toSnakeCase(feature);

    final abstractPath = p.join(
      projectPath,
      'lib/features/$feature/domain/repositories/${featureSnake}_repository.dart',
    );
    final implPath = p.join(
      projectPath,
      'lib/features/$feature/data/repositories/${featureSnake}_repository_impl.dart',
    );

    await Future.wait([
      _scaffoldAbstract(
        filePath: abstractPath,
        pkg: pkg,
        feature: feature,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
      ),
      _scaffoldImpl(
        filePath: implPath,
        pkg: pkg,
        feature: feature,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
      ),
    ]);
  }

  Future<void> _scaffoldAbstract({
    required String filePath,
    required String pkg,
    required String feature,
    required String featurePascal,
    required String featureSnake,
  }) async {
    if (File(filePath).existsSync()) return;
    await FileUtils.writeFile(
      filePath,
      '''
import 'package:fpdart/fpdart.dart';

import 'package:$pkg/error/failures.dart';

abstract class ${featurePascal}Repository {
}
''',
    );
  }

  Future<void> _scaffoldImpl({
    required String filePath,
    required String pkg,
    required String feature,
    required String featurePascal,
    required String featureSnake,
  }) async {
    if (File(filePath).existsSync()) return;
    await FileUtils.writeFile(
      filePath,
      '''
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import 'package:$pkg/error/exceptions.dart';
import 'package:$pkg/error/failures.dart';
import 'package:$pkg/features/$feature/data/datasources/${featureSnake}_remote_datasource.dart';
import 'package:$pkg/features/$feature/domain/repositories/${featureSnake}_repository.dart';

@LazySingleton(as: ${featurePascal}Repository)
class ${featurePascal}RepositoryImpl implements ${featurePascal}Repository {
  const ${featurePascal}RepositoryImpl(this._datasource);

  final ${featurePascal}RemoteDatasource _datasource;
}
''',
    );
  }

  Future<void> addMethod({
    required String projectPath,
    required String pkg,
    required String feature,
    required String endpointName,
    required String endpointType,
  }) async {
    final featurePascal = StringUtils.toPascalCase(feature);
    final endpointPascal = StringUtils.toPascalCase(endpointName);
    final endpointCamel = StringUtils.toCamelCase(endpointName);
    final featureSnake = StringUtils.toSnakeCase(feature);
    final requestClass = '${endpointPascal}Request';
    final responseClass = '${endpointPascal}Response';
    final requestSnake = '${StringUtils.toSnakeCase(endpointName)}_request';
    final responseSnake = '${StringUtils.toSnakeCase(endpointName)}_response';

    final abstractPath = p.join(
      projectPath,
      'lib/features/$feature/domain/repositories/${featureSnake}_repository.dart',
    );
    final implPath = p.join(
      projectPath,
      'lib/features/$feature/data/repositories/${featureSnake}_repository_impl.dart',
    );

    await Future.wait([
      _updateAbstract(
        filePath: abstractPath,
        pkg: pkg,
        feature: feature,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
        endpointCamel: endpointCamel,
        requestClass: requestClass,
        responseClass: responseClass,
        requestSnake: requestSnake,
        responseSnake: responseSnake,
        endpointType: endpointType,
      ),
      _updateImpl(
        filePath: implPath,
        pkg: pkg,
        feature: feature,
        featurePascal: featurePascal,
        featureSnake: featureSnake,
        endpointCamel: endpointCamel,
        requestClass: requestClass,
        responseClass: responseClass,
        requestSnake: requestSnake,
        responseSnake: responseSnake,
        endpointType: endpointType,
      ),
    ]);
  }

  Future<void> _updateAbstract({
    required String filePath,
    required String pkg,
    required String feature,
    required String featurePascal,
    required String featureSnake,
    required String endpointCamel,
    required String requestClass,
    required String responseClass,
    required String requestSnake,
    required String responseSnake,
    required String endpointType,
  }) async {
    final isWs = endpointType == 'websocket';
    final file = File(filePath);
    if (!file.existsSync()) {
      await FileUtils.writeFile(
        filePath,
        '''
import 'package:fpdart/fpdart.dart';

import 'package:$pkg/error/failures.dart';
import 'package:$pkg/features/$feature/data/models/$requestSnake.dart';
import 'package:$pkg/features/$feature/data/models/$responseSnake.dart';

abstract class ${featurePascal}Repository {
}
''',
      );
    }

    await FileUtils.patchFile(filePath, (content) {
      final importBlock =
          "import 'package:$pkg/features/$feature/data/models/$requestSnake.dart';\n"
          "import 'package:$pkg/features/$feature/data/models/$responseSnake.dart';";

      var updated = content;
      if (!updated.contains("'$requestSnake.dart'")) {
        updated = updated.replaceFirst('\nabstract', '\n$importBlock\n\nabstract');
      }

      final newMethod = isWs
          ? '''
  /// Streams [$responseClass] events from the shared WebSocket connection.
  Stream<Either<Failure, $responseClass>> $endpointCamel();
'''
          : '''
  Future<Either<Failure, $responseClass>> $endpointCamel(
    $requestClass request,
  );
''';
      return FileUtils.insertBeforeClassEnd(updated, newMethod);
    });
  }

  Future<void> _updateImpl({
    required String filePath,
    required String pkg,
    required String feature,
    required String featurePascal,
    required String featureSnake,
    required String endpointCamel,
    required String requestClass,
    required String responseClass,
    required String requestSnake,
    required String responseSnake,
    required String endpointType,
  }) async {
    final isWs = endpointType == 'websocket';
    final file = File(filePath);
    if (!file.existsSync()) {
      await FileUtils.writeFile(
        filePath,
        '''
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import 'package:$pkg/error/exceptions.dart';
import 'package:$pkg/error/failures.dart';
import 'package:$pkg/features/$feature/data/datasources/${featureSnake}_remote_datasource.dart';
import 'package:$pkg/features/$feature/domain/repositories/${featureSnake}_repository.dart';

@LazySingleton(as: ${featurePascal}Repository)
class ${featurePascal}RepositoryImpl implements ${featurePascal}Repository {
  const ${featurePascal}RepositoryImpl(this._datasource);

  final ${featurePascal}RemoteDatasource _datasource;
}
''',
      );
    }

    await FileUtils.patchFile(filePath, (content) {
      final importBlock =
          "import 'package:$pkg/features/$feature/data/models/$requestSnake.dart';\n"
          "import 'package:$pkg/features/$feature/data/models/$responseSnake.dart';";

      var updated = content;
      if (!updated.contains("'$requestSnake.dart'")) {
        updated = updated.replaceFirst(
          '\n@LazySingleton',
          '\n$importBlock\n\n@LazySingleton',
        );
      }

      final newMethod = isWs
          ? '''
  @override
  Stream<Either<Failure, $responseClass>> $endpointCamel() async* {
    try {
      yield* _datasource.$endpointCamel().map(Right.new);
    } on UnAuthorizedException catch (e) {
      yield Left(UnAuthorizedFailure(e.message));
    } on AppException catch (e) {
      yield Left(ServerFailure(e.message));
    } catch (e) {
      yield Left(NetworkFailure(e.toString()));
    }
  }
'''
          : '''
  @override
  Future<Either<Failure, $responseClass>> $endpointCamel(
    $requestClass request,
  ) async {
    try {
      final result = await _datasource.$endpointCamel(request);
      return Right(result);
    } on UnAuthorizedException catch (e) {
      return Left(UnAuthorizedFailure(e.message));
    } on ForceUpdateException catch (e) {
      return Left(ForceUpdateFailure(e.message));
    } on MaintenanceException catch (e) {
      return Left(MaintenanceFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
''';
      return FileUtils.insertBeforeClassEnd(updated, newMethod);
    });
  }

}
