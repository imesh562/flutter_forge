import 'dart:io';

import 'package:flutter_forge/src/feature_generator/bloc_generator.dart';
import 'package:flutter_forge/src/feature_generator/datasource_generator.dart';
import 'package:flutter_forge/src/feature_generator/registry_manager.dart';
import 'package:flutter_forge/src/feature_generator/repository_generator.dart';
import 'package:flutter_forge/src/generators/analysis_options_generator.dart';
import 'package:flutter_forge/src/generators/analytics_generator.dart';
import 'package:flutter_forge/src/generators/android_generator.dart';
import 'package:flutter_forge/src/generators/di_generator.dart';
import 'package:flutter_forge/src/generators/entrypoint_generator.dart';
import 'package:flutter_forge/src/generators/exception_generator.dart';
import 'package:flutter_forge/src/generators/firebase_generator.dart';
import 'package:flutter_forge/src/generators/ios_generator.dart';
import 'package:flutter_forge/src/generators/navigation_generator.dart';
import 'package:flutter_forge/src/generators/networking_generator.dart';
import 'package:flutter_forge/src/generators/pubspec_generator.dart';
import 'package:flutter_forge/src/generators/storage_generator.dart';
import 'package:flutter_forge/src/generators/structure_generator.dart';
import 'package:flutter_forge/src/generators/theme_generator.dart';
import 'package:flutter_forge/src/generators/vscode_generator.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/process_utils.dart';
import 'package:path/path.dart' as p;

final class ProjectGenerator {
  const ProjectGenerator();

  Future<void> run(ProjectConfig config) async {
    await runWithSteps(config, _buildSteps(config));
  }

  /// Executes [steps] in order. If any step throws, deletes the project
  /// directory (rollback) then rethrows the original error.
  ///
  /// Exposed for testing: pass custom steps to verify rollback behaviour
  /// without invoking the real Flutter toolchain.
  Future<void> runWithSteps(
    ProjectConfig config,
    Iterable<Future<void> Function()> steps,
  ) async {
    final projectDir = Directory(config.projectPath);
    try {
      for (final step in steps) {
        await step();
      }
    } catch (e) {
      if (projectDir.existsSync()) {
        stderr.writeln('\n✖ Generation failed — rolling back...');
        await projectDir.delete(recursive: true);
        stderr.writeln('  Removed: ${config.projectPath}');
      }
      rethrow;
    }
  }

  List<Future<void> Function()> _buildSteps(ProjectConfig config) => [
        () async {
          stdout.writeln('── Step 1/14  Creating Flutter project ─────────────────');
          await ProcessUtils.run('flutter', [
            'create',
            '--org',
            config.orgIdentifier,
            '--project-name',
            config.projectName,
            config.projectPath,
          ]);
        },
        () async {
          stdout.writeln('── Step 2/14  Removing default entrypoint ───────────────');
          await FileUtils.deleteIfExists(
            p.join(config.projectPath, 'lib', 'main.dart'),
          );
        },
        () async {
          stdout.writeln('── Step 3/14  Scaffolding Clean Architecture tree ───────');
          await StructureGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 4/14  Writing pubspec.yaml ──────────────────────');
          await PubspecGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 5/14  Writing analysis_options.yaml ─────────────');
          await AnalysisOptionsGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 6/14  Generating flavor entrypoints ─────────────');
          await EntrypointGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 7/14  Generating exception hierarchy ────────────');
          await ExceptionGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 8/14  Generating networking layer ───────────────');
          await NetworkingGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 9/14  Generating storage services ───────────────');
          await StorageGenerator().run(config);
        },
        () async {
          if (config.useFirebase) {
            stdout.writeln('── Step 10/14 Generating Firebase & push services ───────');
            await FirebaseGenerator().run(config);
          } else {
            stdout.writeln('── Step 10/14 Firebase skipped ──────────────────────────');
          }
        },
        () async {
          stdout.writeln('── Step 11/14 Generating analytics services ─────────────');
          await AnalyticsGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 12/14 Generating navigation ─────────────────────');
          await NavigationGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 13/14 Generating DI setup ───────────────────────');
          await DiGenerator().run(config);
        },
        () async {
          stdout.writeln('── Step 14/14 Generating theme & shared providers ───────');
          await ThemeGenerator().run(config);
        },
        () async {
          stdout.writeln('── Patching Android build files ─────────────────────────');
          await AndroidGenerator().run(config);
        },
        () async {
          stdout.writeln('── Creating iOS flavor schemes ──────────────────────────');
          await IosGenerator().run(config);
        },
        () async {
          stdout.writeln('── Writing IDE run configurations ───────────────────────');
          await VscodeGenerator().run(config);
        },
        () async {
          stdout.writeln('── Initialising codegen registry ────────────────────────');
          await FileUtils.writeJson(
            p.join(config.projectPath, 'codegen_registry.json'),
            RegistryManager.initialRegistry(),
          );
        },
        () async {
          stdout.writeln('── Scaffolding initial feature files ────────────────────');
          await _scaffoldInitialFeatures(config);
        },
        () async {
          stdout.writeln('── Running flutter pub get ───────────────────────────────');
          await ProcessUtils.run(
            'flutter',
            ['pub', 'get'],
            workingDirectory: config.projectPath,
          );
        },
        () async {
          stdout.writeln('── Formatting generated code ─────────────────────────────');
          await ProcessUtils.run(
            'dart',
            ['format', 'lib/'],
            workingDirectory: config.projectPath,
          );
        },
        () async {
          _printNextSteps(config);
        },
      ];

  Future<void> _scaffoldInitialFeatures(ProjectConfig config) async {
    final projectPath = config.projectPath;
    final pkg = config.projectName;
    final registry = RegistryManager(projectPath);
    final datasourceGen = DatasourceGenerator();
    final repoGen = RepositoryGenerator();
    final blocGen = BlocGenerator();

    for (final feature in ['auth', 'onboarding']) {
      await datasourceGen.scaffold(
        projectPath: projectPath,
        pkg: pkg,
        feature: feature,
      );
      await repoGen.scaffold(
        projectPath: projectPath,
        pkg: pkg,
        feature: feature,
      );
      await blocGen.createBloc(
        projectPath: projectPath,
        pkg: pkg,
        feature: feature,
        blocName: feature,
      );
      await registry.setPrimaryBloc(feature, feature, 'bloc');
    }
  }

  void _printNextSteps(ProjectConfig config) {
    final useFirebase = config.useFirebase;
    final useFlavors = config.useFlavors;
    final appName = config.appDisplayName;

    final firebaseSteps = useFirebase
        ? (useFlavors
            ? '''
║  1. Add google-services.json for each flavor:            ║
║     android/app/src/dev/google-services.json             ║
║     android/app/src/stg/google-services.json             ║
║     android/app/src/preProd/google-services.json         ║
║     android/app/src/prod/google-services.json            ║
║                                                          ║
║  2. Add GoogleService-Info.plist for each flavor:        ║
║     ios/config/dev/GoogleService-Info.plist              ║
║     ios/config/stg/GoogleService-Info.plist              ║
║     ios/config/preProd/GoogleService-Info.plist          ║
║     ios/config/prod/GoogleService-Info.plist             ║
║                                                          ║'''
            : '''
║  1. Add google-services.json:                            ║
║     android/app/google-services.json                     ║
║                                                          ║
║  2. Add GoogleService-Info.plist:                        ║
║     ios/GoogleService-Info.plist                         ║
║                                                          ║''')
        : '';

    final runStep = useFlavors
        ? '''
║  ${useFirebase ? '4' : '2'}. Run a flavor:                                        ║
║     flutter run --flavor dev --target lib/main_dev.dart  ║'''
        : '''
║  ${useFirebase ? '3' : '1'}. Run the app:                                         ║
║     flutter run                                          ║''';

    final codegenStep = '''
║  ${useFirebase ? '3' : (useFlavors ? '3' : '2')}. Run code generation:                                  ║
║     dart run build_runner build \\                        ║
║       --delete-conflicting-outputs                       ║''';

    final featureStep = '''
║  ${useFirebase ? '5' : (useFlavors ? '4' : '3')}. Add features:                                        ║
║     dart pub global run flutter_forge:generate           ║''';

    // On Windows the pub-cache bin dir is often missing from PATH, so surface
    // the universal fallback command rather than the shortcut alias.
    final windowsNote = Platform.isWindows
        ? '''
║                                                          ║
║  Windows tip: if flutter_forge_generate is not found,   ║
║  add the Dart pub cache to your PATH:                    ║
║  %LOCALAPPDATA%\\Pub\\Cache\\bin                           ║
║  or always use the full command above.                   ║'''
        : '';

    stdout.writeln('''

╔══════════════════════════════════════════════════════════╗
║  ✔  $appName scaffold complete!
╠══════════════════════════════════════════════════════════╣
║  Next steps:                                             ║
║                                                          ║
$firebaseSteps$codegenStep
║                                                          ║
$runStep
║                                                          ║
$featureStep$windowsNote
╚══════════════════════════════════════════════════════════╝
''');
  }
}
