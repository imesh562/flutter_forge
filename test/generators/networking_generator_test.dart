import 'dart:io';

import 'package:flutter_forge/src/generators/networking_generator.dart';
import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ProjectConfig _makeConfig(String outputDir) => ProjectConfig(
      projectName: 'test_app',
      appDisplayName: 'Test App',
      orgIdentifier: 'com.example',
      outputDirectory: outputDir,
      flavorSettings: [
        const FlavorSettings(
          flavor: Flavor.prod,
          bundleId: 'com.example.testapp',
          baseUrl: 'https://api.example.com',
          wsUrl: 'wss://api.example.com',
        ),
      ],
      useFirebase: false,
      useFlavors: false,
    );

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('networking_gen_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('NetworkingGenerator', () {
    test('scaffolds a NetworkInfo service backed by connectivity_plus',
        () async {
      final config = _makeConfig(tmp.path);
      await NetworkingGenerator().run(config);

      final file = File(
        p.join(config.projectPath, 'lib/core/network/network_info.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains("import 'package:connectivity_plus/connectivity_plus.dart';"));
      expect(content, contains('class NetworkInfo'));
      expect(content, contains('@lazySingleton'));
      expect(content, contains('Future<bool> get isConnected'));
    });

    test('scaffolds a WebhookHelper that pools connections by path',
        () async {
      final config = _makeConfig(tmp.path);
      await NetworkingGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/network/webhook_helper.dart'),
      ).readAsString();

      // One socket per distinct path, all sharing the flavor's base wsUrl.
      expect(content, contains('final _connections = <String, _SocketConnection>{};'));
      expect(
        content,
        contains('Stream<Map<String, dynamic>> streamFor([String path = \'\']) =>'),
      );
      // Empty path connects to the base URL itself — no endpoint segment.
      expect(content, contains('if (path.isEmpty) return base;'));
      expect(content, contains('FlavorConfig.instance.wsUrl'));
    });

    test('ApiHelper.delete and MockApiHelper.delete both accept queryParameters',
        () async {
      final config = _makeConfig(tmp.path);
      await NetworkingGenerator().run(config);

      final apiHelper = await File(
        p.join(config.projectPath, 'lib/core/network/api_helper.dart'),
      ).readAsString();
      final mockApiHelper = await File(
        p.join(config.projectPath, 'lib/core/network/mock_api_helper.dart'),
      ).readAsString();

      // A DELETE endpoint with a request body sends it as query parameters
      // (datasource_generator.dart) — both delete() overrides must accept it.
      expect(apiHelper, contains('Map<String, dynamic>? queryParameters'));
      expect(
        apiHelper,
        contains('_dio.delete<T>(\n        path,\n        queryParameters: queryParameters,'),
      );
      expect(
        mockApiHelper,
        contains('super.delete(path, queryParameters: queryParameters, options: options)'),
      );
    });
  });

  group('NetworkingGenerator — mock/real switching in every environment', () {
    test('ApiHelper is not registered on its own (no env-gated @LazySingleton)',
        () async {
      final config = _makeConfig(tmp.path);
      await NetworkingGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/network/api_helper.dart'),
      ).readAsString();

      expect(content, isNot(contains('@LazySingleton')));
      expect(content, isNot(contains('env:')));
    });

    test('MockApiHelper is registered as ApiHelper with no environment restriction',
        () async {
      final config = _makeConfig(tmp.path);
      await NetworkingGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/network/mock_api_helper.dart'),
      ).readAsString();

      expect(content, contains('@LazySingleton(as: ApiHelper)'));
      expect(content, isNot(contains('env:')));
    });

    test('mock_config.dart documents the flag as global, not DEV-only',
        () async {
      final config = _makeConfig(tmp.path);
      await NetworkingGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/network/mock_config.dart'),
      ).readAsString();

      expect(content, contains('bool kUseMockApi = false;'));
      expect(content, isNot(contains('DEV flavor')));
    });
  });
}
