import 'package:flutter_forge/src/models/flavor_config.dart';

final class ProjectConfig {
  const ProjectConfig({
    required this.projectName,
    required this.appDisplayName,
    required this.orgIdentifier,
    required this.outputDirectory,
    required this.flavorSettings,
    required this.useFirebase,
    required this.useFlavors,
  });

  /// snake_case Flutter project name — used for directory and pubspec name.
  final String projectName;

  /// Human-readable name shown in app bars and run configs.
  final String appDisplayName;

  /// Reverse-domain org prefix passed to `flutter create --org`.
  final String orgIdentifier;

  /// Absolute path where the generated project will be created.
  final String outputDirectory;

  /// One entry per active flavor. Exactly four when [useFlavors] is true,
  /// exactly one (Flavor.prod) when [useFlavors] is false.
  final List<FlavorSettings> flavorSettings;

  /// Whether to integrate Firebase (push notifications + analytics).
  final bool useFirebase;

  /// Whether to scaffold multiple flavors (DEV / STG / PRE_PROD / PROD).
  final bool useFlavors;

  String get projectPath => '$outputDirectory/$projectName';

  /// True when at least one flavor has a non-empty Mixpanel token.
  bool get hasMixpanel =>
      flavorSettings.any((s) => s.mixpanelToken?.isNotEmpty ?? false);

  FlavorSettings settingsFor(Flavor flavor) =>
      flavorSettings.firstWhere((s) => s.flavor == flavor);
}
