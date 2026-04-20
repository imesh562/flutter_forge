import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Creates the full Clean Architecture directory tree with .gitkeep files.
final class StructureGenerator {
  Future<void> run(ProjectConfig config) async {
    final root = config.projectPath;
    final lib = p.join(root, 'lib');

    final dirs = [
      // Core
      p.join(lib, 'core', 'network'),
      p.join(lib, 'core', 'storage'),
      p.join(lib, 'core', 'analytics'),
      p.join(lib, 'core', 'notifications'),
      p.join(lib, 'core', 'di'),
      // Flavors
      p.join(lib, 'flavors'),
      // Features
      for (final feature in ['auth', 'onboarding']) ...[
        p.join(lib, 'features', feature, 'presentation', 'pages'),
        p.join(lib, 'features', feature, 'presentation', 'widgets'),
        p.join(lib, 'features', feature, 'domain', 'entities'),
        p.join(lib, 'features', feature, 'domain', 'repositories'),
        p.join(lib, 'features', feature, 'domain', 'usecases'),
        p.join(lib, 'features', feature, 'data', 'models'),
        p.join(lib, 'features', feature, 'data', 'datasources'),
        p.join(lib, 'features', feature, 'data', 'repositories'),
      ],
      // Navigation
      p.join(lib, 'navigation'),
      // Shared
      p.join(lib, 'shared', 'widgets'),
      p.join(lib, 'shared', 'theme'),
      p.join(lib, 'shared', 'providers'),
      p.join(lib, 'shared', 'blocs'),
      // Error / utils
      p.join(lib, 'error'),
      p.join(lib, 'utils'),
      // Asset directories
      p.join(root, 'animations'),
      p.join(root, 'images', 'svg'),
      p.join(root, 'images', 'png'),
      p.join(root, 'assets', 'sounds'),
    ];

    for (final dir in dirs) {
      await FileUtils.ensureDir(dir);
    }
  }
}
