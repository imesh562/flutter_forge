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
      // Always write a base strings.xml so android:label="@string/app_name"
      // is satisfied for both flavor and non-flavor builds.
      _writeMainStrings(config),
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

  /// Writes `android/app/src/main/res/values/strings.xml` with the base
  /// `app_name` string.  This satisfies the `@string/app_name` reference in
  /// AndroidManifest.xml for non-flavor builds; flavor builds override it with
  /// per-flavor strings.xml files written by [_writeFlavorStrings].
  Future<void> _writeMainStrings(ProjectConfig config) async {
    final dir = p.join(
      config.projectPath, 'android', 'app', 'src', 'main', 'res', 'values',
    );
    await FileUtils.ensureDir(dir);
    await FileUtils.writeFile(
      p.join(dir, 'strings.xml'),
      '<?xml version="1.0" encoding="utf-8"?>\n'
          '<resources>\n'
          '    <string name="app_name">${config.appDisplayName}</string>\n'
          '</resources>\n',
    );
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

      // Pin NDK to 27.0.12077973 — the minimum version required by
      // flutter_secure_storage, firebase_*, flutter_local_notifications,
      // shared_preferences_android, and path_provider_android.
      // flutter.ndkVersion resolves to whatever NDK Flutter ships with; on
      // older Flutter installs that can be NDK 26.x, which breaks all of the
      // above plugins at build time. Pinning the explicit version guarantees
      // the correct NDK regardless of Flutter SDK version. NDK versions are
      // backward-compatible, so plugins that only need an older version still
      // work fine against 27.
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
      // Use a regex so any VERSION_XX value and any line-ending style are matched.
      if (!result.contains('isCoreLibraryDesugaringEnabled')) {
        result = result.replaceFirstMapped(
          RegExp(r'targetCompatibility\s*=\s*JavaVersion\.VERSION_\d+'),
          (m) => '${m[0]}\n        isCoreLibraryDesugaringEnabled = true',
        );
      }
      if (!result.contains('coreLibraryDesugaring')) {
        const dep =
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")';
        // Prefer injecting into an existing dependencies block so we never
        // create a duplicate block (which Gradle rejects).
        final existingDeps = RegExp(r'(dependencies\s*\{)');
        if (existingDeps.hasMatch(result)) {
          result = result.replaceFirstMapped(
            existingDeps,
            (m) => '${m[0]}\n$dep',
          );
        } else {
          // No dependencies block yet — create one after the flutter { source }
          // block.  Use a regex so whitespace and \r\n line endings are tolerated.
          final flutterSourceRe = RegExp(
            r'flutter\s*\{\s*source\s*=\s*"\.\./\.\."\s*\}',
            multiLine: true,
          );
          if (flutterSourceRe.hasMatch(result)) {
            result = result.replaceFirstMapped(
              flutterSourceRe,
              (m) => '${m[0]}\n\ndependencies {\n$dep\n}',
            );
          } else {
            // Fallback: append a dependencies block at the end of the file.
            result = '$result\n\ndependencies {\n$dep\n}';
          }
        }
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

      // Bump Kotlin to 2.1.0. Firebase's play-services-measurement artifacts
      // (firebase_analytics, firebase_core, firebase_messaging) ship Kotlin
      // metadata compiled at version 2.1.0. If the project Kotlin Gradle
      // Plugin is older than 2.1.0 the build fails with:
      //   "Module was compiled with an incompatible version of Kotlin.
      //    The binary version of its metadata is 2.1.0, expected version is 1.8.0"
      // Kotlin 2.1.0 is backward-compatible with older plugins, so bumping is safe.
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
