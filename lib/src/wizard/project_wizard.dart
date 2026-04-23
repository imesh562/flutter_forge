import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';

/// Drives the interactive setup wizard and returns a validated [ProjectConfig].
final class ProjectWizard {
  // Async stdin reader — avoids blocking the event loop on Windows where
  // stdin.readLineSync() prevents pending stdout writes from being flushed.
  final _lines = StreamIterator<String>(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );

  Future<String> _readLine() async {
    await _lines.moveNext();
    return _lines.current;
  }

  Future<ProjectConfig> collect() async {
    _printHeader();

    final projectName = await _prompt(
      'Project name (snake_case)',
      validate: (v) {
        if (!StringUtils.isSnakeCase(v)) {
          return 'Must be snake_case (lowercase letters, digits, underscores).';
        }
        return null;
      },
    );

    final appDisplayName = await _prompt('App display name');

    final outputDirectory = await _prompt(
      'Output directory (absolute path where the project folder will be created)',
      defaultValue: Directory.current.path,
      validate: (v) {
        if (!Directory(v).existsSync()) return 'Directory does not exist.';
        return null;
      },
    );

    final useFirebase = await _promptYesNo('Integrate Firebase?');
    final useFlavors =
        await _promptYesNo('Use multiple flavors (DEV / STG / PRE_PROD / PROD)?');

    List<FlavorSettings> flavorSettings;

    if (useFlavors) {
      // Collect DEV first to derive org, then reuse as hint for the rest.
      _printSection('DEV flavor');
      final devSettings = await _collectFlavorSettings(Flavor.dev);

      final orgIdentifier = StringUtils.extractOrg(devSettings.bundleId);
      stdout.writeln('  → Derived org identifier: $orgIdentifier');

      _printSection('STG flavor');
      final stgSettings =
          await _collectFlavorSettings(Flavor.stg, orgHint: orgIdentifier);

      _printSection('PRE_PROD flavor');
      final preProdSettings =
          await _collectFlavorSettings(Flavor.preProd, orgHint: orgIdentifier);

      _printSection('PROD flavor');
      final prodSettings =
          await _collectFlavorSettings(Flavor.prod, orgHint: orgIdentifier);

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
      final proceed = await _promptYesNo('Proceed with generation?');
      if (!proceed) {
        stdout.writeln('\nAborted.');
        await _lines.cancel();
        exit(0);
      }
      // Cancel the stdin subscription so the process can exit cleanly after
      // the generator finishes.
      await _lines.cancel();
      return config;
    } else {
      _printSection('Project settings');
      final settings = await _collectSingleSettings();
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
      final proceed = await _promptYesNo('Proceed with generation?');
      if (!proceed) {
        stdout.writeln('\nAborted.');
        await _lines.cancel();
        exit(0);
      }
      // Cancel the stdin subscription so the process can exit cleanly after
      // the generator finishes.
      await _lines.cancel();
      return config;
    }
  }

  // ── Flavor settings collection ────────────────────────────────────────────

  Future<FlavorSettings> _collectFlavorSettings(
    Flavor flavor, {
    String? orgHint,
  }) async {
    final label = flavor.label;

    final bundleId = await _prompt(
      '$label bundle / package ID',
      hint: orgHint != null ? '$orgHint.myapp.${flavor.envName}' : null,
      validate: (v) {
        if (!StringUtils.isValidBundleId(v)) {
          return 'Must be a reverse-domain identifier with at least three segments.';
        }
        return null;
      },
    );

    final baseUrl = await _prompt(
      '$label base API URL (https://...)',
      validate: (v) =>
          StringUtils.isValidUrl(v) ? null : 'Must be a valid https:// URL.',
    );

    final wsUrl = await _prompt(
      '$label WebSocket URL (wss://...)',
      validate: (v) =>
          StringUtils.isValidWsUrl(v) ? null : 'Must be a valid wss:// URL.',
    );

    final mixpanelToken = await _promptOptional('  Mixpanel token for $label');

    return FlavorSettings(
      flavor: flavor,
      bundleId: bundleId,
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      mixpanelToken: mixpanelToken,
    );
  }

  Future<FlavorSettings> _collectSingleSettings() async {
    final bundleId = await _prompt(
      'Bundle / package ID',
      validate: (v) {
        if (!StringUtils.isValidBundleId(v)) {
          return 'Must be a reverse-domain identifier with at least three segments.';
        }
        return null;
      },
    );

    final baseUrl = await _prompt(
      'Base API URL (https://...)',
      validate: (v) =>
          StringUtils.isValidUrl(v) ? null : 'Must be a valid https:// URL.',
    );

    final wsUrl = await _prompt(
      'WebSocket URL (wss://...)',
      validate: (v) =>
          StringUtils.isValidWsUrl(v) ? null : 'Must be a valid wss:// URL.',
    );

    final mixpanelToken = await _promptOptional('Mixpanel token');

    return FlavorSettings(
      flavor: Flavor.prod,
      bundleId: bundleId,
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      mixpanelToken: mixpanelToken,
    );
  }

  // ── Prompt helpers ─────────────────────────────────────────────────────────

  Future<String> _prompt(
    String label, {
    String? defaultValue,
    String? hint,
    String? Function(String)? validate,
  }) async {
    while (true) {
      final displayHint =
          hint != null ? ' [$hint]' : (defaultValue != null ? ' [$defaultValue]' : '');
      stdout.write('  $label$displayHint: ');
      final raw = (await _readLine()).trim();
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
  Future<String?> _promptOptional(String label) async {
    stdout.write('  $label (press Enter to skip): ');
    final raw = (await _readLine()).trim();
    return raw.isEmpty ? null : raw;
  }

  Future<bool> _promptYesNo(String label, {bool defaultYes = true}) async {
    final options = defaultYes ? '[Y/n]' : '[y/N]';
    stdout.write('\n  $label $options: ');
    final raw = (await _readLine()).trim().toLowerCase();
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
