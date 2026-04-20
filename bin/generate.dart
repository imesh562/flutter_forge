import 'dart:io';

import 'package:flutter_forge/src/feature_generator/feature_wizard.dart';
import 'package:flutter_forge/src/feature_generator/registry_manager.dart';
import 'package:flutter_forge/src/utils/process_utils.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--version') || args.contains('-v')) {
    stdout.writeln('1.0.0');
    return;
  }

  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('''
flutter_forge_generate — Generate code inside a flutter_forge project

Usage:
  flutter_forge_generate [project-path]

Description:
  Interactive wizard for adding code to an existing flutter_forge project.
  Run from the project root, or pass the project path as an argument.

Options:
  1. Endpoint (REST or WebSocket)   Generate models, datasource, repository & BLoC wiring
  2. New feature scaffold           Create the Clean Architecture folder tree for a feature
  3. Empty widget                   Create a blank StatelessWidget file
  4. Empty screen (page)            Create a blank screen/page file
  5. Update request/response model  Regenerate a Freezed model with new fields
  6. Rename feature                 Rename a feature folder and update all imports
  7. Delete feature                 Remove a feature folder from disk and registry

Examples:
  flutter_forge_generate
  flutter_forge_generate /path/to/my_app
''');
    return;
  }

  final projectPath = (args.isNotEmpty && args.first != '--help' && args.first != '-h')
      ? args.first
      : Directory.current.path;

  if (!RegistryManager.registryExists(projectPath)) {
    stderr.writeln(
      '✖ codegen_registry.json not found in: $projectPath\n'
      '  Run this command from the root of a flutter_forge project,\n'
      '  or pass the project path as the first argument:\n'
      '    dart run flutter_forge_generate <path>',
    );
    exit(1);
  }

  final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    stderr.writeln(
      '✖ pubspec.yaml not found in: $projectPath\n'
      '  Make sure you are running this from a flutter_forge project root.',
    );
    exit(1);
  }
  final pkg = _extractPackageName(await pubspecFile.readAsString());

  try {
    await FeatureWizard(projectPath, pkg).run();
  } on Exception catch (e) {
    stderr.writeln('\n✖ $e');
    exit(1);
  } catch (e) {
    stderr.writeln('\n✖ Unexpected error: $e');
    exit(1);
  }

  stdout.writeln('\n── Formatting generated code ────────────────────────────');
  await ProcessUtils.run(
    'dart',
    ['format', 'lib/'],
    workingDirectory: projectPath,
  );
}

String _extractPackageName(String pubspecContent) {
  final yaml = loadYaml(pubspecContent);
  if (yaml is! Map) {
    throw StateError('pubspec.yaml is not a valid YAML map.');
  }
  final name = yaml['name'];
  if (name is! String || name.isEmpty) {
    throw StateError('Could not determine package name from pubspec.yaml.');
  }
  return name;
}
