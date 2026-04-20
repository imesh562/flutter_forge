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
  });
}
