import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:test/test.dart';

ProjectConfig _makeConfig({
  required bool useFlavors,
  List<FlavorSettings>? flavorSettings,
  bool useFirebase = false,
}) =>
    ProjectConfig(
      projectName: 'test_app',
      appDisplayName: 'Test App',
      orgIdentifier: 'com.example',
      outputDirectory: '/tmp',
      flavorSettings: flavorSettings ??
          [
            const FlavorSettings(
              flavor: Flavor.prod,
              bundleId: 'com.example.testapp',
              baseUrl: 'https://api.example.com',
              wsUrl: 'wss://api.example.com',
            ),
          ],
      useFirebase: useFirebase,
      useFlavors: useFlavors,
    );

void main() {
  group('ProjectConfig.settingsFor', () {
    test('returns the matching FlavorSettings when present', () {
      final config = _makeConfig(
        useFlavors: true,
        flavorSettings: Flavor.values
            .map(
              (f) => FlavorSettings(
                flavor: f,
                bundleId: 'com.example.testapp',
                baseUrl: 'https://api.example.com',
                wsUrl: 'wss://api.example.com',
              ),
            )
            .toList(),
      );

      expect(config.settingsFor(Flavor.stg).flavor, Flavor.stg);
    });

    test('throws a clear StateError — not a bare "No element" — for a '
        'flavor missing from flavorSettings', () {
      final config = _makeConfig(useFlavors: false); // only Flavor.prod

      expect(
        () => config.settingsFor(Flavor.dev),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('DEV'), contains('flavorSettings.first')),
          ),
        ),
      );
    });
  });

  group('ProjectConfig.hasMixpanel', () {
    test('false when no flavor has a token', () {
      expect(_makeConfig(useFlavors: false).hasMixpanel, isFalse);
    });

    test('true when at least one flavor has a non-empty token', () {
      final config = _makeConfig(
        useFlavors: false,
        flavorSettings: [
          const FlavorSettings(
            flavor: Flavor.prod,
            bundleId: 'com.example.testapp',
            baseUrl: 'https://api.example.com',
            wsUrl: 'wss://api.example.com',
            mixpanelToken: 'abc123',
          ),
        ],
      );
      expect(config.hasMixpanel, isTrue);
    });
  });
}
