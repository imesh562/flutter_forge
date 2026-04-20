import 'dart:io';

import 'package:flutter_forge/src/feature_generator/model_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late ModelGenerator gen;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('model_gen_test_');
    gen = ModelGenerator();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('ModelGenerator.generateRequest', () {
    test('creates a file with correct class name and fields', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [
          {'name': 'email', 'type': 'String'},
          {'name': 'password', 'type': 'String'},
        ],
      );

      final file = File(
        p.join(tmp.path, 'lib/features/auth/data/models/login_request.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('final class LoginRequest'));
      expect(content, contains('final String email;'));
      expect(content, contains('final String password;'));
      expect(content, contains("part 'login_request.g.dart'"));
      expect(content, contains('@JsonSerializable'));
    });

    test('creates file for endpointName with multiple words', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'getUserProfile',
        fields: [],
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/user/data/models/get_user_profile_request.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('final class GetUserProfileRequest'));
    });

    test('throws StateError if file already exists and forceOverwrite is false',
        () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [],
      );

      expect(
        () => gen.generateRequest(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'auth',
          endpointName: 'login',
          fields: [],
        ),
        throwsStateError,
      );
    });

    test('overwrites file when forceOverwrite is true', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [{'name': 'email', 'type': 'String'}],
      );

      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [{'name': 'token', 'type': 'String'}],
        forceOverwrite: true,
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/data/models/login_request.dart'),
      ).readAsString();
      expect(content, contains('final String token;'));
      expect(content, isNot(contains('final String email;')));
    });
  });

  group('ModelGenerator.generateResponse', () {
    test('creates a response file with nullable fields', () async {
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [
          {'name': 'token', 'type': 'String'},
          {'name': 'userId', 'type': 'int'},
        ],
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/data/models/login_response.dart'),
      ).readAsString();

      expect(content, contains('final class LoginResponse extends Equatable'));
      // Response fields are nullable.
      expect(content, contains('final String? token;'));
      expect(content, contains('final int? userId;'));
      expect(content, contains('List<Object?> get props => [token, userId]'));
    });

    test('generates valid file with empty field list', () async {
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'profile',
        endpointName: 'getProfile',
        fields: [],
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/profile/data/models/get_profile_response.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('final class GetProfileResponse'));
      expect(content, contains('List<Object?> get props => []'));
    });
  });
}
