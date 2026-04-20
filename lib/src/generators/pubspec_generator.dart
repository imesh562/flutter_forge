import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

final class PubspecGenerator {
  Future<void> run(ProjectConfig config) async {
    final firebaseDeps = config.useFirebase
        ? '''
  # Firebase
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3
  firebase_analytics: ^11.3.3
  flutter_local_notifications: ^17.2.3
'''
        : '';

    final mixpanelDep = config.hasMixpanel
        ? '''
  # Analytics
  mixpanel_flutter: ^2.3.1
'''
        : '';

    final content = '''
name: ${config.projectName}
description: ${config.appDisplayName}
version: 0.0.1+1
publish_to: none

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_bloc: ^8.1.6
  equatable: ^2.0.5

  # Dependency injection
  get_it: ^7.7.0
  injectable: ^2.4.4

  # Networking
  dio: ^5.7.0
  web_socket_channel: ^3.0.1

  # Navigation
  go_router: ^14.2.7

  # Storage
  flutter_secure_storage: ^9.2.2
  hive_flutter: ^1.1.0
  shared_preferences: ^2.3.3
$firebaseDeps$mixpanelDep
  # UI / utilities
  flutter_screenutil: ^5.9.3
  provider: ^6.1.2
  fpdart: ^1.1.0
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  very_good_analysis: ^6.0.0
  build_runner: ^2.4.13
  injectable_generator: ^2.6.2
  json_serializable: ^6.8.0
  hive_generator: ^2.0.1
  bloc_test: ^9.1.7
  mocktail: ^1.0.4

flutter:
  uses-material-design: true

  assets:
    - animations/
    - images/svg/
    - images/png/
    - assets/sounds/
''';

    await FileUtils.writeFile(
      p.join(config.projectPath, 'pubspec.yaml'),
      content,
    );
  }
}
