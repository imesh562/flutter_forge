import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

/// Creates the full Clean Architecture directory tree with .gitkeep files.
final class StructureGenerator {
  Future<void> run(ProjectConfig config) async {
    final root = config.projectPath;
    final lib = '$root/lib';

    final dirs = [
      // Core
      '$lib/core/network',
      '$lib/core/storage',
      '$lib/core/analytics',
      '$lib/core/notifications',
      '$lib/core/di',
      // Flavors
      '$lib/flavors',
      // Features
      for (final feature in ['auth', 'onboarding']) ...[
        '$lib/features/$feature/presentation/pages',
        '$lib/features/$feature/presentation/widgets',
        '$lib/features/$feature/domain/entities',
        '$lib/features/$feature/domain/repositories',
        '$lib/features/$feature/domain/usecases',
        '$lib/features/$feature/data/models',
        '$lib/features/$feature/data/datasources',
        '$lib/features/$feature/data/repositories',
      ],
      // Navigation
      '$lib/navigation',
      // Shared
      '$lib/shared/widgets',
      '$lib/shared/theme',
      '$lib/shared/providers',
      '$lib/shared/blocs',
      // Error / utils
      '$lib/error',
      '$lib/utils',
      // Asset directories
      '$root/animations',
      '$root/images/svg',
      '$root/images/png',
      '$root/assets/sounds',
    ];

    for (final dir in dirs) {
      await FileUtils.ensureDir(dir);
    }
  }
}
