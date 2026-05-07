import 'dart:io';

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
      _patchGradleWrapper(config),
      _patchAndroidManifest(config),
      _relocateMainActivity(config),
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

      // Remove taskAffinity="" — it prevents the launcher from finding the
      // existing task when the app is in the background, causing Android to
      // spawn a new task that immediately closes, making the app appear to
      // vanish instead of resuming.
      result = result.replaceAll(
        RegExp(r'\n\s*android:taskAffinity=""\s*'),
        '\n',
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

  /// Moves MainActivity.kt from the flutter-generated package path to the
  /// one matching [prodBundleId], and updates its package declaration.
  ///
  /// `flutter create --org com.foo my_app` places MainActivity at
  /// `kotlin/com/foo/my_app/MainActivity.kt`. When the namespace/applicationId
  /// is changed to e.g. `com.foo.app`, Android resolves `.MainActivity` in the
  /// manifest to `com.foo.app.MainActivity`, which won't match the compiled
  /// class at `com.foo.my_app.MainActivity` — causing ActivityNotFoundException.
  Future<void> _relocateMainActivity(ProjectConfig config) async {
    final prodBundleId = config.useFlavors
        ? config.settingsFor(Flavor.prod).bundleId
        : config.flavorSettings.first.bundleId;

    final kotlinRoot = p.join(
      config.projectPath, 'android', 'app', 'src', 'main', 'kotlin',
    );

    // Find the existing MainActivity.kt wherever flutter create put it.
    final existing = Directory(kotlinRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path) == 'MainActivity.kt')
        .firstOrNull;
    if (existing == null) return;

    final newDir = p.join(
      kotlinRoot,
      prodBundleId.replaceAll('.', '/'),
    );
    final newPath = p.join(newDir, 'MainActivity.kt');

    if (existing.path == newPath) return;

    await Directory(newDir).create(recursive: true);
    await File(newPath).writeAsString(
      'package $prodBundleId\n\n'
      'import io.flutter.embedding.android.FlutterActivity\n\n'
      'class MainActivity : FlutterActivity()\n',
    );

    // Remove the old file and its now-empty parent directories.
    final oldDir = existing.parent;
    await existing.delete();
    if (oldDir.listSync().isEmpty) await oldDir.delete(recursive: true);
  }

  Future<void> _patchAppBuildGradle(ProjectConfig config) async {
    final path = p.join(config.projectPath, 'android', 'app', 'build.gradle.kts');

    await FileUtils.patchFile(path, (content) {
      var result = content;

      // Pin compileSdk to 36 — required by androidx.core:core-ktx:1.18.0+.
      // flutter.compileSdkVersion resolves to 35 on current Flutter SDKs,
      // which causes a build failure at checkAarMetadata.
      if (result.contains('flutter.compileSdkVersion')) {
        result = result.replaceFirst('flutter.compileSdkVersion', '36');
      }

      // Pin minSdk to 23 — required by firebase-auth:23.2.1+.
      // flutter.minSdkVersion resolves to 21, which causes a manifest merger
      // failure at build time.
      if (result.contains('flutter.minSdkVersion')) {
        result = result.replaceFirst('flutter.minSdkVersion', '23');
      }

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

      // flutter create derives applicationId from --org + project-name (e.g.
      // com.example.my_app), which will not match the bundle ID the user
      // registered in Firebase or the App Store. Always replace it with the
      // user-specified prod bundle ID so google-services.json and signing
      // configs align from the first build on every machine.
      final prodBundleId = config.useFlavors
          ? config.settingsFor(Flavor.prod).bundleId
          : config.flavorSettings.first.bundleId;
      result = result.replaceFirstMapped(
        RegExp(r'namespace\s*=\s*"[^"]*"'),
        (_) => 'namespace = "$prodBundleId"',
      );
      result = result.replaceFirstMapped(
        RegExp(r'applicationId\s*=\s*"[^"]*"'),
        (_) => 'applicationId = "$prodBundleId"',
      );

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

      // Bump AGP to 8.9.1 — required by androidx.core:core-ktx:1.18.0+.
      // Flutter's default is 8.7.0, which fails checkAarMetadata.
      result = result.replaceFirstMapped(
        RegExp(r'id\("com\.android\.application"\)\s+version\s+"[^"]*"'),
        (m) => 'id("com.android.application") version "8.9.1"',
      );

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

  Future<void> _patchGradleWrapper(ProjectConfig config) async {
    final path = p.join(
      config.projectPath,
      'android',
      'gradle',
      'wrapper',
      'gradle-wrapper.properties',
    );
    await FileUtils.patchFile(path, (content) {
      // Bump Gradle wrapper to 8.11.1 — minimum required by AGP 8.9.1.
      // Flutter's default (8.10.2) causes "Minimum supported Gradle version
      // is 8.11.1" at build time.
      return content.replaceFirstMapped(
        RegExp(r'gradle-[\d.]+-(all|bin)\.zip'),
        (m) => 'gradle-8.11.1-${m[1]}.zip',
      );
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
