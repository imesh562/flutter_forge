import 'dart:io';

import 'package:flutter_forge/src/generators/analytics_generator.dart';
import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ProjectConfig _makeConfig(
  String outputDir, {
  bool useFirebase = false,
  String? mixpanelToken,
}) =>
    ProjectConfig(
      projectName: 'test_app',
      appDisplayName: 'Test App',
      orgIdentifier: 'com.example',
      outputDirectory: outputDir,
      flavorSettings: [
        FlavorSettings(
          flavor: Flavor.prod,
          bundleId: 'com.example.testapp',
          baseUrl: 'https://api.example.com',
          wsUrl: 'wss://api.example.com',
          mixpanelToken: mixpanelToken,
        ),
      ],
      useFirebase: useFirebase,
      useFlavors: false,
    );

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('analytics_gen_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('AnalyticsGenerator', () {
    test('does not write a dead CompositeAnalyticsService when no provider is enabled',
        () async {
      final config = _makeConfig(tmp.path);
      await AnalyticsGenerator().run(config);

      final composite = File(
        p.join(config.projectPath, 'lib/core/analytics/composite_analytics_service.dart'),
      );
      expect(composite.existsSync(), isFalse);

      // The interface itself is always written.
      final interface = File(
        p.join(config.projectPath, 'lib/core/analytics/analytics_service.dart'),
      );
      expect(interface.existsSync(), isTrue);
    });

    test('writes CompositeAnalyticsService wired to Firebase only when useFirebase is true',
        () async {
      final config = _makeConfig(tmp.path, useFirebase: true);
      await AnalyticsGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/analytics/composite_analytics_service.dart'),
      ).readAsString();

      expect(content, contains('this._firebase'));
      expect(content, isNot(contains('_mixpanel')));
    });

    test('writes CompositeAnalyticsService wired to Mixpanel only when a token is set',
        () async {
      final config = _makeConfig(tmp.path, mixpanelToken: 'token123');
      await AnalyticsGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/analytics/composite_analytics_service.dart'),
      ).readAsString();

      expect(content, contains('this._mixpanel'));
      expect(content, isNot(contains('_firebase')));
    });

    test('wires both providers when Firebase and Mixpanel are both enabled', () async {
      final config = _makeConfig(tmp.path, useFirebase: true, mixpanelToken: 'token123');
      await AnalyticsGenerator().run(config);

      final content = await File(
        p.join(config.projectPath, 'lib/core/analytics/composite_analytics_service.dart'),
      ).readAsString();

      expect(content, contains('List<AnalyticsService> get _services => [_firebase, _mixpanel];'));
    });
  });
}
