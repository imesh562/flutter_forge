enum Flavor { dev, stg, preProd, prod }

extension FlavorExtension on Flavor {
  String get envName => switch (this) {
        Flavor.dev => 'dev',
        Flavor.stg => 'stg',
        Flavor.preProd => 'preProd',
        Flavor.prod => 'prod',
      };

  String get label => switch (this) {
        Flavor.dev => 'DEV',
        Flavor.stg => 'STG',
        Flavor.preProd => 'PRE_PROD',
        Flavor.prod => 'PROD',
      };

  /// Gradle product flavor name (no underscores, camelCase).
  String get gradleName => switch (this) {
        Flavor.dev => 'dev',
        Flavor.stg => 'stg',
        Flavor.preProd => 'preProd',
        Flavor.prod => 'prod',
      };

  String get dartEntrypoint => switch (this) {
        Flavor.dev => 'lib/main_dev.dart',
        Flavor.stg => 'lib/main_stg.dart',
        Flavor.preProd => 'lib/main_pre_prod.dart',
        Flavor.prod => 'lib/main_prod.dart',
      };
}

final class FlavorSettings {
  const FlavorSettings({
    required this.flavor,
    required this.bundleId,
    required this.baseUrl,
    required this.wsUrl,
    this.mixpanelToken,
  });

  final Flavor flavor;
  final String bundleId;
  final String baseUrl;
  final String wsUrl;

  /// Null when Mixpanel is not used for this flavor.
  final String? mixpanelToken;
}
