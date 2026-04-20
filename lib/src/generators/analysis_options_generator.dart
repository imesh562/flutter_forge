import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

final class AnalysisOptionsGenerator {
  Future<void> run(ProjectConfig config) async {
    await FileUtils.writeFile(
      p.join(config.projectPath, 'analysis_options.yaml'),
      '''
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - lib/core/di/injection.config.dart
    - "**/*.g.dart"
    - "**/*.freezed.dart"
''',
    );
  }
}
