import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

/// Patches Android build files for product flavors and/or google-services.
final class AndroidGenerator {
  Future<void> run(ProjectConfig config) async {
    await Future.wait([
      _patchAppBuildGradle(config),
      _patchSettingsGradle(config),
      _patchAndroidManifest(config),
      if (config.useFlavors) _writeFlavorStrings(config),
      if (config.useFirebase) _patchProjectBuildGradle(config),
    ]);
  }

  Future<void> _patchAndroidManifest(ProjectConfig config) async {
    final path = p.join(
      config.projectPath, 'android', 'app', 'src', 'main', 'AndroidManifest.xml',
    );
    await FileUtils.patchFile(path, (content) {
      var result = content.replaceFirst(
        RegExp(r'android:label="[^"]*"'),
        'android:label="@string/app_name"',
      );
      // Required for Android 13+ runtime notification permission.
      if (!result.contains('POST_NOTIFICATIONS')) {
        result = result.replaceFirst(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
              '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
        );
      }
      return result;
    });
  }

  Future<void> _writeFlavorStrings(ProjectConfig config) async {
    final appName = config.appDisplayName;
    for (final flavor in Flavor.values) {
      final isProd = flavor == Flavor.prod;
      final label = isProd ? appName : '$appName ${flavor.label}';
      final dir = p.join(
        config.projectPath, 'android', 'app', 'src', flavor.gradleName, 'res', 'values',
      );
      await FileUtils.ensureDir(dir);
      await FileUtils.writeFile(
        p.join(dir, 'strings.xml'),
        '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <string name="app_name">$label</string>\n'
            '</resources>\n',
      );
    }
  }

  Future<void> _patchAppBuildGradle(ProjectConfig config) async {
    final path = p.join(config.projectPath, 'android', 'app', 'build.gradle.kts');

    await FileUtils.patchFile(path, (content) {
      var result = content;

      // Pin NDK to the version required by common plugins (e.g. flutter_secure_storage).
      // flutter create already emits `ndkVersion = flutter.ndkVersion`, so we
      // replace that sentinel rather than checking for absence.
      if (result.contains('flutter.ndkVersion')) {
        result = result.replaceFirst(
          'flutter.ndkVersion',
          '"27.0.12077973"',
        );
      } else if (!result.contains('ndkVersion')) {
        result = result.replaceFirst(
          'android {',
          'android {\n    ndkVersion = "27.0.12077973"',
        );
      }

      // Enable core library desugaring required by flutter_local_notifications.
      if (!result.contains('isCoreLibraryDesugaringEnabled')) {
        result = result.replaceFirst(
          'targetCompatibility = JavaVersion.VERSION_11',
          'targetCompatibility = JavaVersion.VERSION_11\n'
              '        isCoreLibraryDesugaringEnabled = true',
        );
      }
      if (!result.contains('coreLibraryDesugaring')) {
        result = result.replaceFirst(
          'flutter {\n    source = "../.."\n}',
          'flutter {\n    source = "../.."\n}\n\n'
              'dependencies {\n'
              '    coreLibraryDesugaring'
              '("com.android.tools:desugar_jdk_libs:2.1.4")\n}',
        );
      }

      if (config.useFirebase) {
        result = result.replaceFirst(
          'id("com.android.application")',
          'id("com.android.application")\n    id("com.google.gms.google-services")',
        );
      }

      if (config.useFlavors) {
        final flavorBlock = _buildFlavorBlock(config);
        // Match `buildTypes {` with any leading whitespace so the block is
        // always inserted inside `android {}` regardless of indentation style.
        result = result.replaceFirstMapped(
          RegExp(r'\n([ \t]+buildTypes[ \t]*\{)'),
          (m) => '\n$flavorBlock\n${m[1]}',
        );
      }

      return result;
    });
  }

  Future<void> _patchProjectBuildGradle(ProjectConfig config) async {
    final path = p.join(config.projectPath, 'android', 'build.gradle.kts');

    await FileUtils.patchFile(path, (content) {
      if (!content.contains('google-services')) {
        return '$content\n'
            '// google-services is applied per-module via the plugins {} block '
            'in app/build.gradle.kts\n';
      }
      return content;
    });
  }

  Future<void> _patchSettingsGradle(ProjectConfig config) async {
    final path = p.join(config.projectPath, 'android', 'settings.gradle.kts');

    await FileUtils.patchFile(path, (content) {
      var result = content;

      // Bump Kotlin to 2.1.0 — required by recent Firebase/GMS artifacts.
      result = result.replaceFirstMapped(
        RegExp(r'id\("org\.jetbrains\.kotlin\.android"\)\s+version\s+"[^"]*"'),
        (m) => 'id("org.jetbrains.kotlin.android") version "2.1.0"',
      );

      if (!result.contains('google-services') &&
          result.contains('com.android.application')) {
        result = result.replaceFirstMapped(
          RegExp(r'id\("com\.android\.application"\)[^\n]*'),
          (m) =>
              '${m[0]}\n    id("com.google.gms.google-services") version "4.4.0" apply false',
        );
      }

      return result;
    });
  }

  String _buildFlavorBlock(ProjectConfig config) {
    final buf = StringBuffer()
      ..writeln('    flavorDimensions += "app"')
      ..writeln()
      ..writeln('    productFlavors {');

    for (final flavor in Flavor.values) {
      final s = config.settingsFor(flavor);
      buf
        ..writeln('        create("${flavor.gradleName}") {')
        ..writeln('            dimension = "app"')
        ..writeln('            applicationId = "${s.bundleId}"');
      if (flavor != Flavor.prod) {
        buf.writeln(
          '            versionNameSuffix = "-${flavor.gradleName}"',
        );
      }
      buf.writeln('        }');
    }

    buf.writeln('    }');
    return buf.toString();
  }

}
