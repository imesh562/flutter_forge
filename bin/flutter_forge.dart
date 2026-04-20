import 'dart:io';

import 'package:flutter_forge/src/project_generator.dart';
import 'package:flutter_forge/src/wizard/project_wizard.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--version') || args.contains('-v')) {
    stdout.writeln('1.0.0');
    return;
  }

  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('''
flutter_forge — Scaffold a new production-grade Flutter project

Usage:
  flutter_forge

Description:
  Interactive wizard that creates a full Flutter project with:
    • Clean Architecture folder structure
    • Flavors (dev / stg / preProd / prod)
    • Networking, storage, navigation, DI, theme
    • Optional Firebase & analytics setup
    • Android & iOS flavor config
    • VS Code run configurations

Run with no arguments to start the wizard.
''');
    return;
  }

  final config = await ProjectWizard().collect();

  // Guard against accidentally overwriting an existing project.
  if (Directory(config.projectPath).existsSync()) {
    stderr.writeln(
      '\n✖ Directory already exists: ${config.projectPath}\n'
      '  Delete it or choose a different project name.',
    );
    exit(1);
  }

  try {
    await ProjectGenerator().run(config);
  } on Exception catch (e) {
    stderr.writeln('\n✖ $e');
    exit(1);
  } catch (e) {
    stderr.writeln('\n✖ Unexpected error: $e');
    exit(1);
  }
}
