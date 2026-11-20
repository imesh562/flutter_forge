import 'dart:io';

import 'package:flutter_forge/src/generators/entrypoint_generator.dart';
import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ProjectConfig _makeConfig(String outputDir, {required bool useFlavors}) => ProjectConfig(
      projectName: 'test_app',
      appDisplayName: 'Test App',
      orgIdentifier: 'com.example',
      outputDirectory: outputDir,
      flavorSettings: useFlavors
          ? Flavor.values
              .map(
                (f) => FlavorSettings(
                  flavor: f,
                  bundleId: 'com.example.testapp',
                  baseUrl: 'https://api.example.com',
                  wsUrl: 'wss://api.example.com',
                ),
              )
              .toList()
          : [
              const FlavorSettings(
                flavor: Flavor.prod,
                bundleId: 'com.example.testapp',
                baseUrl: 'https://api.example.com',
                wsUrl: 'wss://api.example.com',
              ),
            ],
      useFirebase: false,
      useFlavors: useFlavors,
    );

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('entrypoint_gen_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('EntrypointGenerator — Hive initialization', () {
    test('single (flavorless) main.dart initializes Hive before DI', () async {
      final config = _makeConfig(tmp.path, useFlavors: false);
      await EntrypointGenerator().run(config);

      final content =
          await File(p.join(config.projectPath, 'lib/main.dart')).readAsString();

      expect(content, contains("import 'package:test_app/core/storage/hive_service.dart';"));
      expect(content, contains('await HiveService.init();'));
      // Must run before DI configuration, not after.
      expect(
        content.indexOf('await HiveService.init();'),
        lessThan(content.indexOf('await configureInjection(')),
      );
    });

    test('every flavor entrypoint initializes Hive before DI', () async {
      final config = _makeConfig(tmp.path, useFlavors: true);
      await EntrypointGenerator().run(config);

      for (final fileName in ['main_dev', 'main_stg', 'main_pre_prod', 'main_prod']) {
        final content = await File(
          p.join(config.projectPath, 'lib', '$fileName.dart'),
        ).readAsString();

        expect(
          content,
          contains("import 'package:test_app/core/storage/hive_service.dart';"),
          reason: '$fileName.dart missing HiveService import',
        );
        expect(
          content,
          contains('await HiveService.init();'),
          reason: '$fileName.dart never initializes Hive',
        );
        expect(
          content.indexOf('await HiveService.init();'),
          lessThan(content.indexOf('await configureInjection(')),
          reason: '$fileName.dart initializes Hive after DI configuration',
        );
      }
    });
  });
}
