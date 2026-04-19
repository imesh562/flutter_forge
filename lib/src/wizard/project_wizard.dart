import 'dart:io';

import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';

/// Drives the interactive setup wizard and returns a validated [ProjectConfig].
final class ProjectWizard {
  Future<ProjectConfig> collect() async {
    _printHeader();

    final projectName = _prompt(
      'Project name (snake_case)',
      validate: (v) {
        if (!StringUtils.isSnakeCase(v)) {
          return 'Must be snake_case (lowercase letters, digits, underscores).';
        }
        return null;
      },
    );

    final appDisplayName = _prompt('App display name');

    final outputDirectory = _prompt(
      'Output directory (absolute path where the project folder will be created)',
      defaultValue: Directory.current.path,
      validate: (v) {
        if (!Directory(v).existsSync()) return 'Directory does not exist.';
        return null;
      },
    );

    final useFirebase = _promptYesNo('Integrate Firebase?');
    final useFlavors =
        _promptYesNo('Use multiple flavors (DEV / STG / PRE_PROD / PROD)?');

    List<FlavorSettings> flavorSettings;

    if (useFlavors) {
      // Collect DEV first to derive org, then reuse as hint for the rest.
      _printSection('DEV flavor');
      final devSettings = _collectFlavorSettings(Flavor.dev);

      final orgIdentifier = StringUtils.extractOrg(devSettings.bundleId);
      stdout.writeln('  → Derived org identifier: $orgIdentifier');

      _printSection('STG flavor');
      final stgSettings =
          _collectFlavorSettings(Flavor.stg, orgHint: orgIdentifier);

      _printSection('PRE_PROD flavor');
      final preProdSettings =
          _collectFlavorSettings(Flavor.preProd, orgHint: orgIdentifier);

      _printSection('PROD flavor');
      final prodSettings =
          _collectFlavorSettings(Flavor.prod, orgHint: orgIdentifier);

      flavorSettings = [devSettings, stgSettings, preProdSettings, prodSettings];

      final orgIdentifierFinal = orgIdentifier;
      final config = ProjectConfig(
        projectName: projectName,
        appDisplayName: appDisplayName,
        orgIdentifier: orgIdentifierFinal,
        outputDirectory: outputDirectory,
        flavorSettings: flavorSettings,
        useFirebase: useFirebase,
        useFlavors: useFlavors,
      );

      _printSummary(config);
      final proceed = _promptYesNo('Proceed with generation?');
      if (!proceed) {
        stdout.writeln('\nAborted.');
        exit(0);
      }
      return config;
    } else {
      _printSection('Project settings');
      final settings = _collectSingleSettings();
      final orgIdentifier = StringUtils.extractOrg(settings.bundleId);
      stdout.writeln('  → Derived org identifier: $orgIdentifier');

      flavorSettings = [settings];

      final config = ProjectConfig(
        projectName: projectName,
        appDisplayName: appDisplayName,
        orgIdentifier: orgIdentifier,
        outputDirectory: outputDirectory,
        flavorSettings: flavorSettings,
        useFirebase: useFirebase,
        useFlavors: useFlavors,
      );

      _printSummary(config);
      final proceed = _promptYesNo('Proceed with generation?');
      if (!proceed) {
        stdout.writeln('\nAborted.');
        exit(0);
      }
      return config;
    }
  }

  // ── Flavor settings collection ────────────────────────────────────────────

  FlavorSettings _collectFlavorSettings(Flavor flavor, {String? orgHint}) {
    final label = flavor.label;

    final bundleId = _prompt(
      '$label bundle / package ID',
      hint: orgHint != null ? '$orgHint.myapp.${flavor.envName}' : null,
      validate: (v) {
        if (!StringUtils.isValidBundleId(v)) {
          return 'Must be a reverse-domain identifier with at least three segments.';
        }
        return null;
      },
    );

    final baseUrl = _prompt(
      '$label base API URL (https://...)',
      validate: (v) =>
          StringUtils.isValidUrl(v) ? null : 'Must be a valid https:// URL.',
    );

    final wsUrl = _prompt(
      '$label WebSocket URL (wss://...)',
      validate: (v) =>
          StringUtils.isValidWsUrl(v) ? null : 'Must be a valid wss:// URL.',
    );

    final mixpanelToken = _promptOptional('  Mixpanel token for $label');

    return FlavorSettings(
      flavor: flavor,
      bundleId: bundleId,
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      mixpanelToken: mixpanelToken,
    );
  }

  FlavorSettings _collectSingleSettings() {
    final bundleId = _prompt(
      'Bundle / package ID',
      validate: (v) {
        if (!StringUtils.isValidBundleId(v)) {
          return 'Must be a reverse-domain identifier with at least three segments.';
        }
        return null;
      },
    );

    final baseUrl = _prompt(
      'Base API URL (https://...)',
      validate: (v) =>
          StringUtils.isValidUrl(v) ? null : 'Must be a valid https:// URL.',
    );

    final wsUrl = _prompt(
      'WebSocket URL (wss://...)',
      validate: (v) =>
          StringUtils.isValidWsUrl(v) ? null : 'Must be a valid wss:// URL.',
    );

    final mixpanelToken = _promptOptional('Mixpanel token');

    return FlavorSettings(
      flavor: Flavor.prod,
      bundleId: bundleId,
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      mixpanelToken: mixpanelToken,
    );
  }

  // ── Prompt helpers ─────────────────────────────────────────────────────────

  String _prompt(
    String label, {
    String? defaultValue,
    String? hint,
    String? Function(String)? validate,
  }) {
    while (true) {
      final displayHint =
          hint != null ? ' [$hint]' : (defaultValue != null ? ' [$defaultValue]' : '');
      stdout.write('  $label$displayHint: ');
      final raw = stdin.readLineSync()?.trim() ?? '';
      final value = raw.isEmpty ? (defaultValue ?? '') : raw;

      if (value.isEmpty) {
        stdout.writeln('  ✖ Cannot be empty.');
        continue;
      }

      final error = validate?.call(value);
      if (error != null) {
        stdout.writeln('  ✖ $error');
        continue;
      }

      return value;
    }
  }

  /// Returns null when the user presses Enter without input.
  String? _promptOptional(String label) {
    stdout.write('  $label (press Enter to skip): ');
    final raw = stdin.readLineSync()?.trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  bool _promptYesNo(String label, {bool defaultYes = true}) {
    final options = defaultYes ? '[Y/n]' : '[y/N]';
    stdout.write('\n  $label $options: ');
    final raw = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    if (raw.isEmpty) return defaultYes;
    return raw == 'y' || raw == 'yes';
  }

  void _printHeader() {
    stdout.writeln('''
╔══════════════════════════════════════════╗
║       flutter_forge — Project Setup      ║
╚══════════════════════════════════════════╝
''');
  }

  void _printSection(String title) {
    stdout.writeln('\n── $title ──');
  }

  void _printSummary(ProjectConfig config) {
    stdout
      ..writeln('\n══ Configuration Summary ═══════════════════')
      ..writeln('  Project:    ${config.projectName}')
      ..writeln('  App name:   ${config.appDisplayName}')
      ..writeln('  Org:        ${config.orgIdentifier}')
      ..writeln('  Output:     ${config.projectPath}')
      ..writeln('  Firebase:   ${config.useFirebase ? "yes" : "no"}')
      ..writeln('  Flavors:    ${config.useFlavors ? "yes" : "no"}')
      ..writeln('  Mixpanel:   ${config.hasMixpanel ? "yes" : "no"}');
    for (final s in config.flavorSettings) {
      stdout.writeln(
        '  ${s.flavor.label.padRight(8)}: ${s.bundleId}  ${s.baseUrl}',
      );
    }
    stdout.writeln('════════════════════════════════════════════');
  }
}
