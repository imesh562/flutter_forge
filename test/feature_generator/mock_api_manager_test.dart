import 'dart:io';

import 'package:flutter_forge/src/feature_generator/mock_api_manager.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late MockApiManager manager;
  late File configFile;
  late File responsesFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mock_api_manager_test_');
    manager = MockApiManager(tmp.path);

    final networkDir = p.join(tmp.path, 'lib', 'core', 'network');
    await Directory(networkDir).create(recursive: true);

    configFile = File(p.join(networkDir, 'mock_config.dart'));
    await configFile.writeAsString('bool kUseMockApi = false;\n');

    responsesFile = File(p.join(networkDir, 'mock_responses.dart'));
    await responsesFile.writeAsString(
      'const Map<String, dynamic> kMockResponses = {\n'
      '// <<MOCK_ENTRIES>>\n'
      '};\n',
    );
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('MockApiManager.toggle / isEnabled', () {
    test('isEnabled reflects kUseMockApi', () async {
      expect(await manager.isEnabled(), isFalse);
      await manager.toggle();
      expect(await manager.isEnabled(), isTrue);
      await manager.toggle();
      expect(await manager.isEnabled(), isFalse);
    });
  });

  group('MockApiManager.addResponse — Dart literal escaping', () {
    test('escapes a dollar sign so it is not treated as string interpolation',
        () async {
      await manager.addResponse(
        method: 'GET',
        path: '/price',
        jsonBody: '{"label": "Total: \$50", "template": "\${danger}"}',
      );

      final content = await responsesFile.readAsString();
      // Every literal $ in the source value must be escaped in the emitted
      // Dart literal — otherwise these would be real string interpolation.
      expect(content, contains(r'Total: \$50'));
      expect(content, contains(r'\${danger}'));
    });

    test('escapes single quotes and backslashes without corrupting the literal',
        () async {
      // Decodes to the string value: It's a "test" with a backslash \
      await manager.addResponse(
        method: 'GET',
        path: '/quote',
        jsonBody: '{"text": "It\'s a \\"test\\" with a backslash \\\\"}',
      );

      final content = await responsesFile.readAsString();
      expect(content, contains(r"\'"));
      expect(content, contains(r'\\'));
    });

    test('adds a plain entry retrievable via listKeys', () async {
      await manager.addResponse(
        method: 'POST',
        path: '/auth/login',
        jsonBody: '{"token": "abc123"}',
      );

      expect(await manager.listKeys(), ['POST /auth/login']);
    });

    test('throws when the entry already exists', () async {
      await manager.addResponse(
        method: 'GET',
        path: '/user',
        jsonBody: '{"id": 1}',
      );

      expect(
        () => manager.addResponse(
          method: 'GET',
          path: '/user',
          jsonBody: '{"id": 2}',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('MockApiManager.removeResponse', () {
    test('removes a previously-added entry', () async {
      await manager.addResponse(
        method: 'GET',
        path: '/user',
        jsonBody: '{"id": 1}',
      );
      expect(await manager.listKeys(), ['GET /user']);

      await manager.removeResponse('GET /user');
      expect(await manager.listKeys(), isEmpty);
    });
  });
}
