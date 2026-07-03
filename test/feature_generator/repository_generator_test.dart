import 'dart:io';

import 'package:flutter_forge/src/feature_generator/model_generator.dart';
import 'package:flutter_forge/src/feature_generator/repository_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late RepositoryGenerator gen;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('repo_gen_test_');
    gen = RepositoryGenerator();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('RepositoryGenerator.scaffold', () {
    test('creates both abstract and impl files', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );

      final abstract = File(
        p.join(
          tmp.path,
          'lib/features/auth/domain/repositories/auth_repository.dart',
        ),
      );
      final impl = File(
        p.join(
          tmp.path,
          'lib/features/auth/data/repositories/auth_repository_impl.dart',
        ),
      );

      expect(abstract.existsSync(), isTrue);
      expect(impl.existsSync(), isTrue);

      final abstractContent = await abstract.readAsString();
      expect(abstractContent, contains('abstract class AuthRepository'));

      final implContent = await impl.readAsString();
      expect(implContent, contains('class AuthRepositoryImpl implements AuthRepository'));
      expect(implContent, contains('@LazySingleton(as: AuthRepository)'));
      // Depends on NetworkInfo so methods can fail fast when offline.
      expect(
        implContent,
        contains(
          'const AuthRepositoryImpl(this._datasource, this._networkInfo)',
        ),
      );
      expect(implContent, contains('final NetworkInfo _networkInfo;'));
      expect(
        implContent,
        contains("import 'package:my_app/core/network/network_info.dart';"),
      );
    });

    test('is idempotent — does not overwrite existing files', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );

      final abstract = File(
        p.join(
          tmp.path,
          'lib/features/auth/domain/repositories/auth_repository.dart',
        ),
      );
      await abstract.writeAsString('// custom');

      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );

      expect(await abstract.readAsString(), '// custom');
    });
  });

  group('RepositoryGenerator.addMethod', () {
    Future<void> _createModels(String feature, String endpointName) async {
      final modelGen = ModelGenerator();
      await modelGen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: feature,
        endpointName: endpointName,
        fields: [],
      );
      await modelGen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: feature,
        endpointName: endpointName,
        fields: [{'name': 'token', 'type': 'String'}],
      );
    }

    test('adds REST method signature to abstract and implementation', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );
      await _createModels('auth', 'login');

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        endpointType: 'rest',
      );

      final abstractContent = await File(
        p.join(
          tmp.path,
          'lib/features/auth/domain/repositories/auth_repository.dart',
        ),
      ).readAsString();

      final implContent = await File(
        p.join(
          tmp.path,
          'lib/features/auth/data/repositories/auth_repository_impl.dart',
        ),
      ).readAsString();

      expect(
        abstractContent,
        contains('Future<Either<Failure, LoginResponse>> login('),
      );
      expect(
        implContent,
        contains('Future<Either<Failure, LoginResponse>> login('),
      );
      expect(implContent, contains('return Right(result)'));
      expect(implContent, contains('on UnAuthorizedException'));
      // Fails fast with NetworkFailure before ever touching the datasource.
      expect(implContent, contains('if (!await _networkInfo.isConnected)'));
      expect(
        implContent,
        contains("return Left(NetworkFailure('No internet connection'));"),
      );
    });

    test('adds WebSocket stream method to both files', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'chat',
      );
      await _createModels('chat', 'receiveMessage');

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'chat',
        endpointName: 'receiveMessage',
        endpointType: 'websocket',
      );

      final abstractContent = await File(
        p.join(
          tmp.path,
          'lib/features/chat/domain/repositories/chat_repository.dart',
        ),
      ).readAsString();

      expect(
        abstractContent,
        contains(
          'Stream<Either<Failure, ReceiveMessageResponse>> receiveMessage()',
        ),
      );

      final implContent = await File(
        p.join(
          tmp.path,
          'lib/features/chat/data/repositories/chat_repository_impl.dart',
        ),
      ).readAsString();

      expect(implContent, contains('yield* _datasource.receiveMessage()'));
      expect(implContent, contains('if (!await _networkInfo.isConnected)'));
      expect(
        implContent,
        contains("yield Left(NetworkFailure('No internet connection'));"),
      );
    });

    test('inserts model imports when not already present', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );
      await _createModels('auth', 'login');
      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        endpointType: 'rest',
      );

      final abstractContent = await File(
        p.join(
          tmp.path,
          'lib/features/auth/domain/repositories/auth_repository.dart',
        ),
      ).readAsString();

      expect(abstractContent, contains('login_request.dart'));
      expect(abstractContent, contains('login_response.dart'));
    });

    test('does not duplicate model imports when addMethod runs again for the '
        'same endpoint', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );
      await _createModels('auth', 'login');

      // Call addMethod twice for the same endpoint — e.g. a retry after a
      // partial failure. The "already imported" guard must actually detect
      // the import is already there instead of blindly re-adding it.
      for (var i = 0; i < 2; i++) {
        await gen.addMethod(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'auth',
          endpointName: 'login',
          endpointType: 'rest',
        );
      }

      final abstractContent = await File(
        p.join(
          tmp.path,
          'lib/features/auth/domain/repositories/auth_repository.dart',
        ),
      ).readAsString();
      final implContent = await File(
        p.join(
          tmp.path,
          'lib/features/auth/data/repositories/auth_repository_impl.dart',
        ),
      ).readAsString();

      expect(
        'login_request.dart'.allMatches(abstractContent).length,
        1,
        reason: 'login_request.dart import duplicated in the abstract repository',
      );
      expect(
        'login_response.dart'.allMatches(abstractContent).length,
        1,
        reason: 'login_response.dart import duplicated in the abstract repository',
      );
      expect(
        'login_request.dart'.allMatches(implContent).length,
        1,
        reason: 'login_request.dart import duplicated in the repository impl',
      );
      expect(
        'network_info.dart'.allMatches(implContent).length,
        1,
        reason: 'network_info.dart import duplicated in the repository impl',
      );
    });

    test('retrofits _networkInfo into a repo impl generated before NetworkInfo existed',
        () async {
      // Simulate a repository_impl.dart written by an older version of this
      // tool, before NetworkInfo was added — no field, no import, and a
      // single-arg constructor.
      final implPath = p.join(
        tmp.path,
        'lib/features/auth/data/repositories/auth_repository_impl.dart',
      );
      await File(implPath).create(recursive: true);
      await File(implPath).writeAsString('''
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import 'package:my_app/error/exceptions.dart';
import 'package:my_app/error/failures.dart';
import 'package:my_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:my_app/features/auth/domain/repositories/auth_repository.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._datasource);

  final AuthRemoteDatasource _datasource;
}
''');

      final abstractPath = p.join(
        tmp.path,
        'lib/features/auth/domain/repositories/auth_repository.dart',
      );
      await File(abstractPath).create(recursive: true);
      await File(abstractPath).writeAsString('''
import 'package:fpdart/fpdart.dart';

import 'package:my_app/error/failures.dart';

abstract class AuthRepository {
}
''');

      await _createModels('auth', 'login');
      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        endpointType: 'rest',
      );

      final implContent = await File(implPath).readAsString();

      expect(
        implContent,
        contains("import 'package:my_app/core/network/network_info.dart';"),
      );
      expect(
        implContent,
        contains('const AuthRepositoryImpl(this._datasource, this._networkInfo);'),
      );
      expect(implContent, contains('final NetworkInfo _networkInfo;'));
      // And the new method itself is still wired up correctly.
      expect(implContent, contains('if (!await _networkInfo.isConnected)'));
    });
  });
}
