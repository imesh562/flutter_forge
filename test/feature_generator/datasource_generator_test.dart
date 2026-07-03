import 'dart:io';

import 'package:flutter_forge/src/feature_generator/datasource_generator.dart';
import 'package:flutter_forge/src/feature_generator/model_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late DatasourceGenerator gen;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ds_gen_test_');
    gen = DatasourceGenerator();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('DatasourceGenerator.scaffold', () {
    test('creates remote datasource file with correct class name', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/auth/data/datasources/auth_remote_datasource.dart',
        ),
      );
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('class AuthRemoteDatasource'));
      expect(content, contains('@lazySingleton'));
      expect(content, contains('final ApiHelper _api;'));
    });

    test('is idempotent — does not overwrite existing file', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/auth/data/datasources/auth_remote_datasource.dart',
        ),
      );
      final originalContent = await file.readAsString();

      // Write something custom and call scaffold again.
      await file.writeAsString('// custom');
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );

      expect(await file.readAsString(), '// custom');
      expect(originalContent, isNot('// custom'));
    });

    test('converts multi-word feature name to snake_case filename', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user_profile',
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/user_profile/data/datasources/'
          'user_profile_remote_datasource.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
    });
  });

  group('DatasourceGenerator.addMethod', () {
    Future<void> _createModels(String feature, String endpointName) async {
      final modelGen = ModelGenerator();
      await modelGen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: feature,
        endpointName: endpointName,
        fields: [{'name': 'id', 'type': 'String'}],
      );
      await modelGen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: feature,
        endpointName: endpointName,
        fields: [{'name': 'data', 'type': 'String'}],
      );
    }

    test('adds a REST GET method to existing datasource', () async {
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
        method: 'GET',
        path: '/auth/login',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/auth/data/datasources/auth_remote_datasource.dart',
        ),
      ).readAsString();

      expect(content, contains('Future<LoginResponse> login('));
      expect(content, contains("_api.get<Map<String, dynamic>>("));
      expect(content, contains('queryParameters: request.toJson()'));
      // Regression: imports must not be injected between @lazySingleton and class.
      expect(
        content,
        contains(
          'import \'../models/login_request.dart\';\n'
          'import \'../models/login_response.dart\';\n'
          '\n@lazySingleton\n'
          'class AuthRemoteDatasource',
        ),
      );
    });

    test('adds a POST method with body parameter', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );
      await _createModels('auth', 'register');

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'register',
        method: 'POST',
        path: '/auth/register',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/auth/data/datasources/auth_remote_datasource.dart',
        ),
      ).readAsString();

      expect(content, contains('data: request.toJson()'));
    });

    test('adds a DELETE method with query parameters', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
      );
      await _createModels('auth', 'revokeSession');

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'revokeSession',
        method: 'DELETE',
        path: '/auth/session',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/auth/data/datasources/auth_remote_datasource.dart',
        ),
      ).readAsString();

      // ApiHelper.delete now accepts queryParameters, so this must compile.
      expect(content, contains('_api.delete<Map<String, dynamic>>('));
      expect(content, contains('queryParameters: request.toJson()'));
    });

    test('adds a WebSocket stream method connected to the base URL when path is empty',
        () async {
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
        method: 'GET',
        path: '',
        endpointType: 'websocket',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/chat/data/datasources/chat_remote_datasource.dart',
        ),
      ).readAsString();

      expect(content, contains('Stream<ReceiveMessageResponse> receiveMessage()'));
      expect(content, contains('_ws.streamFor()'));
      expect(content, contains("data['type'] == 'receiveMessage'"));
    });

    test('adds a WebSocket stream method connected to its own endpoint path',
        () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'chat',
      );
      await _createModels('chat', 'receiveMessage');
      await _createModels('chat', 'receiveOrderUpdate');

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'chat',
        endpointName: 'receiveMessage',
        method: 'GET',
        path: '/chat',
        endpointType: 'websocket',
      );
      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'chat',
        endpointName: 'receiveOrderUpdate',
        method: 'GET',
        path: '/orders',
        endpointType: 'websocket',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/chat/data/datasources/chat_remote_datasource.dart',
        ),
      ).readAsString();

      // Distinct paths get their own connection — same base URL, different
      // endpoint segments.
      expect(content, contains("_ws.streamFor('/chat')"));
      expect(content, contains("_ws.streamFor('/orders')"));
    });

    test('substitutes path params into method signature', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
      );
      await _createModels('user', 'getUser');

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'getUser',
        method: 'GET',
        path: '/users/:id',
        endpointType: 'rest',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/user/data/datasources/user_remote_datasource.dart',
        ),
      ).readAsString();

      expect(content, contains('required String id'));
      // Interpolated path: '/users/${id}'
      expect(content, contains(r'${id}'));
    });

    test('fetches and parses a list-shaped response as List<Item>', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
      );
      final modelGen = ModelGenerator();
      await modelGen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'getUsers',
        fields: [{'name': 'id', 'type': 'String'}],
        isList: true,
        itemClassName: 'User',
      );

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'getUsers',
        method: 'GET',
        path: '/users',
        endpointType: 'rest',
        hasRequest: false,
        responseIsList: true,
        responseItemClassName: 'User',
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/user/data/datasources/user_remote_datasource.dart',
        ),
      ).readAsString();

      expect(content, contains('Future<GetUsersResponse> getUsers()'));
      expect(content, contains('_api.get<List<dynamic>>('));
      expect(
        content,
        contains('.map((e) => User.fromJson(e as Map<String, dynamic>))'),
      );
      expect(content, contains('.toList()'));
      expect(content, isNot(contains('GetUsersResponse.fromJson')));
    });

    test('serializes a list-shaped request body as a JSON array', () async {
      await gen.scaffold(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
      );
      final modelGen = ModelGenerator();
      await modelGen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'bulkCreateUsers',
        fields: [{'name': 'name', 'type': 'String'}],
        isList: true,
        itemClassName: 'NewUser',
      );
      await modelGen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'bulkCreateUsers',
        fields: [{'name': 'created', 'type': 'int'}],
      );

      await gen.addMethod(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'bulkCreateUsers',
        method: 'POST',
        path: '/users/bulk',
        endpointType: 'rest',
        requestIsList: true,
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/user/data/datasources/user_remote_datasource.dart',
        ),
      ).readAsString();

      expect(
        content,
        contains('data: request.map((e) => e.toJson()).toList()'),
      );
    });
  });
}
