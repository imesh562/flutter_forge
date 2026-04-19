import 'dart:convert';

import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';

final class VscodeGenerator {
  Future<void> run(ProjectConfig config) async {
    await Future.wait([
      _writeLaunchJson(config),
      _writeAndroidStudioRunConfigs(config),
    ]);
  }

  Future<void> _writeLaunchJson(ProjectConfig config) async {
    final List<Map<String, Object>> configurations;

    if (config.useFlavors) {
      configurations = Flavor.values
          .map(
            (f) => {
              'name': '${config.appDisplayName} ${f.label}',
              'request': 'launch',
              'type': 'dart',
              'args': [
                '--flavor',
                f.gradleName,
                '--target',
                f.dartEntrypoint,
              ],
            },
          )
          .toList();
    } else {
      configurations = [
        {
          'name': config.appDisplayName,
          'request': 'launch',
          'type': 'dart',
        },
      ];
    }

    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert({
      'version': '0.2.0',
      'configurations': configurations,
    });

    await FileUtils.writeFile(
      '${config.projectPath}/.vscode/launch.json',
      '$json\n',
    );
  }

  Future<void> _writeAndroidStudioRunConfigs(ProjectConfig config) async {
    if (config.useFlavors) {
      for (final flavor in Flavor.values) {
        await FileUtils.writeFile(
          '${config.projectPath}/.run/${config.appDisplayName} ${flavor.label}.run.xml',
          '''
<component name="ProjectRunConfigurationManager">
  <configuration default="false"
                 name="${config.appDisplayName} ${flavor.label}"
                 type="FlutterRunConfigurationType"
                 factoryName="Flutter">
    <option name="additionalArgs"
            value="--flavor ${flavor.gradleName} --target ${flavor.dartEntrypoint}" />
    <option name="filePath"
            value="\$PROJECT_DIR\$/${flavor.dartEntrypoint}" />
    <method v="2" />
  </configuration>
</component>
''',
        );
      }
    } else {
      await FileUtils.writeFile(
        '${config.projectPath}/.run/${config.appDisplayName}.run.xml',
        '''
<component name="ProjectRunConfigurationManager">
  <configuration default="false"
                 name="${config.appDisplayName}"
                 type="FlutterRunConfigurationType"
                 factoryName="Flutter">
    <option name="filePath"
            value="\$PROJECT_DIR\$/lib/main.dart" />
    <method v="2" />
  </configuration>
</component>
''',
      );
    }
  }
}
