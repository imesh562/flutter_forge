import 'dart:io';

import 'package:flutter_forge/src/generators/pubspec_generator.dart';
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
    tmp = await Directory.systemTemp.createTemp('pubspec_gen_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('PubspecGenerator', () {
    test('declares a connectivity_plus dependency', () async {
      final config = _makeConfig(tmp.path);
      await PubspecGenerator().run(config);

      final content =
          await File(p.join(config.projectPath, 'pubspec.yaml')).readAsString();
      expect(content, contains('connectivity_plus:'));
    });
  });
}
