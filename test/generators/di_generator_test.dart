import 'dart:io';

import 'package:flutter_forge/src/generators/di_generator.dart';
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
    tmp = await Directory.systemTemp.createTemp('di_gen_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('DiGenerator', () {
    test('registers NetworkInfo in the compilable injection.config.dart stub',
        () async {
      final config = _makeConfig(tmp.path);
      await DiGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/di/injection.config.dart'),
      ).readAsString();

      expect(content, contains("import '../network/network_info.dart'"));
      expect(
        content,
        contains('gh.lazySingleton<_i_net.NetworkInfo>(() => const _i_net.NetworkInfo());'),
      );
    });

    test(
        'registers MockApiHelper as the single ApiHelper impl, unconditionally',
        () async {
      final config = _makeConfig(tmp.path);
      await DiGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/di/injection.config.dart'),
      ).readAsString();

      expect(
        content,
        contains('gh.lazySingleton<_i938.ApiHelper>(() => _i_mock.MockApiHelper());'),
      );
      // No registerFor / environment restriction on the ApiHelper binding.
      expect(content, isNot(contains("registerFor: {_stg")));
      expect(content, isNot(contains("registerFor: {_dev}")));
    });
  });
}
