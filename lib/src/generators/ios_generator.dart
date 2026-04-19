import 'dart:io';
import 'dart:math';

import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';

/// Adds per-flavor Xcode build configurations and schemes for `--flavor` support.
///
/// Flutter requires:
/// 1. Build configurations named `Debug-<flavor>`, `Release-<flavor>`,
///    `Profile-<flavor>` in `project.pbxproj`.
/// 2. A named scheme file for each flavor that references those configurations.
final class IosGenerator {
  final _rng = Random.secure();

  Future<void> run(ProjectConfig config) async {
    final projectDir = '${config.projectPath}/ios/Runner.xcodeproj';
    final pbxprojPath = '$projectDir/project.pbxproj';
    final schemesDir = '$projectDir/xcshareddata/xcschemes';
    final podfilePath = '${config.projectPath}/ios/Podfile';

    await _patchPodfile(podfilePath, config);
    await _patchDeploymentTarget(pbxprojPath);
    await _patchInfoPlist(config);
    await _patchBundleId(pbxprojPath, config);
    if (config.useFirebase) await _writeEntitlements(config);
    if (!config.useFlavors) {
      if (config.useFirebase) {
        await _injectEntitlements(pbxprojPath);
        await _injectFirebaseCopyScript(pbxprojPath);
      }
      return;
    }
    await _patchPbxproj(pbxprojPath);
    await _injectDisplayNames(pbxprojPath, config);
    await _wirePodsXcconfigs(pbxprojPath);
    await _wireProfileXcconfig(pbxprojPath);
    if (config.useFirebase) {
      await _injectEntitlements(pbxprojPath);
      await _injectFirebaseCopyScript(pbxprojPath);
    }
    await _writeSchemes(schemesDir);
  }

  // ── Podfile ────────────────────────────────────────────────────────────────

  Future<void> _patchPodfile(String path, ProjectConfig config) async {
    final file = File(path);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    // Set minimum deployment target (Firebase Analytics requires 13.0+).
    content = content.replaceAll(
      RegExp(r"# platform :ios, '[^']*'"),
      "platform :ios, '13.0'",
    );
    if (!content.contains("platform :ios,")) {
      content = "platform :ios, '13.0'\n$content";
    }

    // Register each flavor build configuration so CocoaPods maps it to the
    // correct build type (debug/release).
    if (config.useFlavors) {
      const flavors = ['dev', 'stg', 'preProd', 'prod'];
      final flavorEntries = StringBuffer();
      for (final type in ['Debug', 'Profile', 'Release']) {
        final mode = type == 'Debug' ? ':debug' : ':release';
        for (final f in flavors) {
          flavorEntries.writeln("  '$type-$f' => $mode,");
        }
      }
      content = content.replaceFirst(
        RegExp(r"project 'Runner',\s*\{[^}]*\}"),
        "project 'Runner', {\n"
            "  'Debug' => :debug,\n"
            "  'Profile' => :release,\n"
            "  'Release' => :release,\n"
            "${flavorEntries.toString().trimRight()}\n}",
      );
    }

    // Enforce deployment target in post_install for all pods.
    content = content.replaceFirst(
      'flutter_additional_ios_build_settings(target)',
      'flutter_additional_ios_build_settings(target)\n'
          '    target.build_configurations.each do |config|\n'
          "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'\n"
          '    end',
    );

    file.writeAsStringSync(content);
  }

  // ── Info.plist ────────────────────────────────────────────────────────────

  Future<void> _patchInfoPlist(ProjectConfig config) async {
    final file = File('${config.projectPath}/ios/Runner/Info.plist');
    if (!file.existsSync()) return;
    final updated = file.readAsStringSync().replaceFirst(
      RegExp(r'<key>CFBundleDisplayName</key>\s*<string>[^<]*</string>'),
      '<key>CFBundleDisplayName</key>\n\t<string>\$(APP_DISPLAY_NAME)</string>',
    );
    file.writeAsStringSync(updated);
  }

  // ── APP_DISPLAY_NAME per build config ─────────────────────────────────────

  Future<void> _injectDisplayNames(
    String path,
    ProjectConfig config,
  ) async {
    final file = File(path);
    if (!file.existsSync()) return;

    final appName = config.appDisplayName;
    final displayNames = <String, String>{
      for (final f in Flavor.values)
        for (final base in ['Debug', 'Release', 'Profile']) ...{
          '$base-${f.gradleName}':
              f == Flavor.prod ? appName : '$appName ${f.label}',
          base: appName,
        },
    };

    var content = file.readAsStringSync();

    // For each Runner target XCBuildConfiguration block (has PRODUCT_BUNDLE_IDENTIFIER,
    // no BUNDLE_LOADER), inject APP_DISPLAY_NAME before the `name =` line.
    content = content.replaceAllMapped(
      RegExp(
        r'(\t\t[0-9A-F]{24} /\* [^*]+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};)',
        dotAll: true,
      ),
      (m) {
        final block = m.group(0)!;
        if (!block.contains('PRODUCT_BUNDLE_IDENTIFIER') ||
            block.contains('BUNDLE_LOADER') ||
            block.contains('APP_DISPLAY_NAME')) return block;
        final nameMatch = RegExp(r'name = "?([^";]+)"?;').firstMatch(block);
        if (nameMatch == null) return block;
        final display = displayNames[nameMatch.group(1)];
        if (display == null) return block;
        // Inject inside buildSettings block (before its closing `};`),
        // not at the XCBuildConfiguration level where `name =` lives.
        return block.replaceFirst(
          '\n\t\t\t};\n\t\t\tname =',
          '\n\t\t\t\tAPP_DISPLAY_NAME = "$display";\n\t\t\t};\n\t\t\tname =',
        );
      },
    );

    file.writeAsStringSync(content);
  }

  // ── Deployment target ─────────────────────────────────────────────────────

  Future<void> _patchDeploymentTarget(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    final updated = file.readAsStringSync().replaceAll(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = \d+\.\d+'),
      'IPHONEOS_DEPLOYMENT_TARGET = 13.0',
    );
    file.writeAsStringSync(updated);
  }

  // ── project.pbxproj ────────────────────────────────────────────────────────

  Future<void> _patchPbxproj(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    // Parse existing XCConfigurationList entries to find which GUIDs belong
    // to which list (Runner project, Runner target, RunnerTests target).
    final lists = _parseConfigLists(content);
    if (lists.isEmpty) return;

    final flavors = Flavor.values.map((f) => f.gradleName).toList();
    const baseNames = ['Debug', 'Release', 'Profile'];

    // Parse all existing XCBuildConfiguration blocks keyed by GUID.
    final blocks = _parseConfigBlocks(content);

    // Generate new GUIDs and build new configuration blocks.
    final newBlocks = <String>[];
    final guidMap = <String, String>{};  // '<listKey>/<flavor>/<base>' -> newGuid

    for (final list in lists) {
      for (final flavor in flavors) {
        for (final base in baseNames) {
          final baseGuid = list.guidFor(base);
          if (baseGuid == null || !blocks.containsKey(baseGuid)) continue;

          final newGuid = _genGuid();
          final key = '${list.name}/$flavor/$base';
          guidMap[key] = newGuid;

          var block = blocks[baseGuid]!;
          block = block.replaceAll(baseGuid, newGuid);
          block = block.replaceAll(
            '\t\t\tname = $base;',
            '\t\t\tname = "$base-$flavor";',
          );
          newBlocks.add(block);
        }
      }
    }

    // Insert new blocks before the section end marker.
    content = content.replaceFirst(
      '/* End XCBuildConfiguration section */',
      '${newBlocks.join('\n')}\n/* End XCBuildConfiguration section */',
    );

    // Add new GUIDs into each XCConfigurationList.
    for (final list in lists) {
      for (final flavor in flavors) {
        for (final base in baseNames) {
          final baseGuid = list.guidFor(base);
          if (baseGuid == null) continue;
          final newGuid = guidMap['${list.name}/$flavor/$base'];
          if (newGuid == null) continue;

          content = content.replaceFirst(
            '\t\t\t$baseGuid /* $base */,',
            '\t\t\t$baseGuid /* $base */,\n\t\t\t$newGuid /* $base-$flavor */,',
          );
        }
      }
    }

    file.writeAsStringSync(content);
  }

  Map<String, String> _parseConfigBlocks(String content) {
    final result = <String, String>{};
    final pattern = RegExp(
      r'(\t\t[0-9A-F]{24} /\* (?:Debug|Release|Profile) \*/ = \{.*?\n\t\t\};)',
      dotAll: true,
    );
    for (final m in pattern.allMatches(content)) {
      final block = m.group(0)!;
      final guidMatch = RegExp(r'([0-9A-F]{24})').firstMatch(block);
      if (guidMatch != null) result[guidMatch.group(1)!] = block;
    }
    return result;
  }

  List<_ConfigList> _parseConfigLists(String content) {
    final result = <_ConfigList>[];
    // Match each XCConfigurationList block
    final listPattern = RegExp(
      r'([0-9A-F]{24}) /\* Build configuration list for (\w+) "(\w+)" \*/ = \{.*?buildConfigurations = \((.*?)\);',
      dotAll: true,
    );
    for (final m in listPattern.allMatches(content)) {
      final entries = m.group(4)!;
      final entryPattern = RegExp(r'([0-9A-F]{24}) /\* (Debug|Release|Profile) \*/');
      final guids = <String, String>{};
      for (final e in entryPattern.allMatches(entries)) {
        guids[e.group(2)!] = e.group(1)!;
      }
      if (guids.length >= 2) {
        result.add(_ConfigList(
          name: '${m.group(2)}_${m.group(3)}',
          listGuid: m.group(1)!,
          guids: guids,
        ));
      }
    }
    return result;
  }

  // ── Per-flavor Flutter xcconfig files + pbxproj wiring ───────────────────

  static const _flavorConfigs = [
    ('Debug',   'dev',     'debug-dev'),
    ('Debug',   'stg',     'debug-stg'),
    ('Debug',   'preProd', 'debug-preprod'),
    ('Debug',   'prod',    'debug-prod'),
    ('Release', 'dev',     'release-dev'),
    ('Release', 'stg',     'release-stg'),
    ('Release', 'preProd', 'release-preprod'),
    ('Release', 'prod',    'release-prod'),
    ('Profile', 'dev',     'profile-dev'),
    ('Profile', 'stg',     'profile-stg'),
    ('Profile', 'preProd', 'profile-preprod'),
    ('Profile', 'prod',    'profile-prod'),
  ];

  Future<void> _wirePodsXcconfigs(String pbxprojPath) async {
    final projectDir = File(pbxprojPath).parent.parent.path; // ios/
    final flutterDir = '$projectDir/Flutter';

    // 1. Create per-flavor Flutter xcconfig files that chain both Pods and Generated.
    //    FLUTTER_TARGET overrides the default lib/main.dart from Generated.xcconfig
    //    so Xcode builds the correct flavor entrypoint without needing `flutter run -t`.
    final flavorEntrypoints = {
      for (final f in Flavor.values) f.gradleName: f.dartEntrypoint,
    };
    final newRefs = <String, (String, String)>{}; // configName -> (guid, filename)
    for (final (base, flavor, podsKey) in _flavorConfigs) {
      final configName = '$base-$flavor';
      final filename = '$configName.xcconfig';
      final entrypoint = flavorEntrypoints[flavor] ?? 'lib/main.dart';
      final file = File('$flutterDir/$filename');
      file.writeAsStringSync(
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.$podsKey.xcconfig"\n'
        '#include "Generated.xcconfig"\n'
        'FLUTTER_TARGET=$entrypoint\n',
      );
      newRefs[configName] = (_genGuid(), filename);
    }

    // 2. Wire into project.pbxproj.
    final pbxproj = File(pbxprojPath);
    var content = pbxproj.readAsStringSync();

    // Insert PBXFileReference entries.
    final refLines = newRefs.entries.map((e) {
      final (guid, filename) = e.value;
      return '\t\t$guid /* $filename */ = {isa = PBXFileReference; '
          'lastKnownFileType = text.xcconfig; name = $filename; '
          'path = Flutter/$filename; sourceTree = "SOURCE_ROOT"; };';
    }).join('\n');
    content = content.replaceFirst(
      '/* End PBXFileReference section */',
      '$refLines\n\t\t/* End PBXFileReference section */',
    );

    // Add new file references to the Flutter PBXGroup children.
    // The Flutter group always contains Debug.xcconfig, Release.xcconfig, Generated.xcconfig.
    // We append our new entries before the closing `);` of that group's children.
    final groupChildrenLines = newRefs.entries
        .map((e) => '\t\t\t\t${e.value.$1} /* ${e.value.$2} */,')
        .join('\n');
    content = content.replaceFirstMapped(
      RegExp(
        r'(isa = PBXGroup;\s*children = \([^)]*?Generated\.xcconfig \*/,)\s*\);',
        dotAll: true,
      ),
      (m) => '${m.group(1)}\n$groupChildrenLines\n\t\t\t);',
    );

    // Update baseConfigurationReference in each Runner flavor build config.
    content = content.replaceAllMapped(
      RegExp(
        r'\t\t[0-9A-F]{24} /\* [^*]+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};',
        dotAll: true,
      ),
      (m) {
        final block = m.group(0)!;
        if (!block.contains('PRODUCT_BUNDLE_IDENTIFIER') ||
            block.contains('BUNDLE_LOADER')) return block;
        final nameMatch = RegExp(r'name = "([^"]+)";').firstMatch(block);
        if (nameMatch == null) return block;
        final ref = newRefs[nameMatch.group(1)];
        if (ref == null) return block;
        final (guid, filename) = ref;
        final baseLine =
            '\t\t\tbaseConfigurationReference = $guid /* $filename */;\n';
        if (block.contains('baseConfigurationReference')) {
          return block.replaceFirst(
            RegExp(r'\t\t\tbaseConfigurationReference = [^;]+;\n'),
            baseLine,
          );
        }
        return block.replaceFirst(
          '\t\t\tisa = XCBuildConfiguration;\n',
          '$baseLine\t\t\tisa = XCBuildConfiguration;\n',
        );
      },
    );

    pbxproj.writeAsStringSync(content);
  }

  // ── Profile xcconfig ──────────────────────────────────────────────────────

  /// Creates `Flutter/Profile.xcconfig` and wires it as the base config for
  /// the Runner target's Profile build configuration, silencing the CocoaPods
  /// warning about `Pods-Runner.profile.xcconfig` not being included.
  Future<void> _wireProfileXcconfig(String pbxprojPath) async {
    final projectDir = File(pbxprojPath).parent.parent.path; // ios/
    final flutterDir = '$projectDir/Flutter';

    // Write Flutter/Profile.xcconfig.
    File('$flutterDir/Profile.xcconfig').writeAsStringSync(
      '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"\n'
      '#include "Generated.xcconfig"\n',
    );

    final guid = _genGuid();
    final pbxproj = File(pbxprojPath);
    var content = pbxproj.readAsStringSync();

    // Add PBXFileReference entry.
    content = content.replaceFirst(
      '/* End PBXFileReference section */',
      '\t\t$guid /* Profile.xcconfig */ = {isa = PBXFileReference; '
          'lastKnownFileType = text.xcconfig; name = Profile.xcconfig; '
          'path = Flutter/Profile.xcconfig; sourceTree = "SOURCE_ROOT"; };\n'
          '\t\t/* End PBXFileReference section */',
    );

    // Add to Flutter group children after Generated.xcconfig.
    content = content.replaceFirst(
      RegExp(r'(Generated\.xcconfig \*/,)(\s*\);[\s\S]*?name = Flutter;)'),
      '\$1\n\t\t\t\t$guid /* Profile.xcconfig */,\$2',
    );

    // Update the Runner target Profile build config to use Profile.xcconfig.
    content = content.replaceAllMapped(
      RegExp(
        r'(\t\t[0-9A-F]{24} /\* Profile \*/ = \{\n\t\t\tisa = XCBuildConfiguration;\n)'
        r'(\t\t\tbaseConfigurationReference = [^\n]+Release\.xcconfig[^\n]+;\n)',
      ),
      (m) =>
          '${m.group(1)}'
          '\t\t\tbaseConfigurationReference = $guid /* Profile.xcconfig */;\n',
    );

    pbxproj.writeAsStringSync(content);
  }

  // ── Bundle ID ─────────────────────────────────────────────────────────────

  Future<void> _patchBundleId(String path, ProjectConfig config) async {
    final file = File(path);
    if (!file.existsSync()) return;

    // flutter create sets bundle ID to `<org>.<projectName>`.
    // Replace the trailing project-name segment with "app".
    final oldId = '${config.orgIdentifier}.${config.projectName}';
    final newId = '${config.orgIdentifier}.app';

    var content = file.readAsStringSync();
    content = content
        .replaceAll('$oldId.RunnerTests', '$newId.RunnerTests')
        .replaceAll(oldId, newId);
    file.writeAsStringSync(content);
  }

  // ── Scheme files ──────────────────────────────────────────────────────────

  Future<void> _writeSchemes(String schemesDir) async {
    final runnerScheme = File('$schemesDir/Runner.xcscheme');
    if (!runnerScheme.existsSync()) return;

    final template = runnerScheme.readAsStringSync();

    for (final flavor in Flavor.values) {
      final fn = flavor.gradleName;
      var scheme = template
          .replaceAll('buildConfiguration = "Debug"',   'buildConfiguration = "Debug-$fn"')
          .replaceAll('buildConfiguration = "Release"', 'buildConfiguration = "Release-$fn"')
          .replaceAll('buildConfiguration = "Profile"', 'buildConfiguration = "Profile-$fn"');
      // Scheme file name must match --flavor argument Flutter passes to xcodebuild.
      File('$schemesDir/$fn.xcscheme').writeAsStringSync(scheme);
    }
  }

  // ── Push notification entitlements ───────────────────────────────────────

  Future<void> _writeEntitlements(ProjectConfig config) async {
    final file = File('${config.projectPath}/ios/Runner/Runner.entitlements');
    file.writeAsStringSync('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>aps-environment</key>
\t<string>development</string>
</dict>
</plist>
''');
  }

  Future<void> _injectEntitlements(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();
    if (content.contains('CODE_SIGN_ENTITLEMENTS')) return;

    // Inject into every Runner target build config block (has
    // PRODUCT_BUNDLE_IDENTIFIER, no BUNDLE_LOADER).
    content = content.replaceAllMapped(
      RegExp(
        r'(\t\t[0-9A-F]{24} /\* [^*]+ \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};)',
        dotAll: true,
      ),
      (m) {
        final block = m.group(0)!;
        if (!block.contains('PRODUCT_BUNDLE_IDENTIFIER') ||
            block.contains('BUNDLE_LOADER') ||
            block.contains('CODE_SIGN_ENTITLEMENTS')) return block;
        return block.replaceFirst(
          '\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER',
          '\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER',
        );
      },
    );

    file.writeAsStringSync(content);
  }

  // ── Firebase GoogleService-Info.plist copy script ─────────────────────────

  Future<void> _injectFirebaseCopyScript(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    var content = file.readAsStringSync();

    // Skip if already injected.
    if (content.contains('Copy Firebase GoogleService-Info.plist')) return;

    const guid = 'FA0B1C2D3E4F5A6B7C8D9E0F';
    const phaseEntry =
        '\t\tFA0B1C2D3E4F5A6B7C8D9E0F /* Copy Firebase GoogleService-Info.plist */,\n';

    // 1. Add phase definition before the section end marker.
    final phaseDef = '''
\t\tFA0B1C2D3E4F5A6B7C8D9E0F /* Copy Firebase GoogleService-Info.plist */ = {
\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\tinputPaths = (
\t\t\t);
\t\t\tname = "Copy Firebase GoogleService-Info.plist";
\t\t\toutputPaths = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\tshellPath = /bin/sh;
\t\t\tshellScript = "FLAVOR=\$(echo \\"\$CONFIGURATION\\" | sed 's/Debug-//' | sed 's/Release-//' | sed 's/Profile-//')\\nSRC=\\"\${PROJECT_DIR}/config/\${FLAVOR}/GoogleService-Info.plist\\"\\nDST=\\"\${BUILT_PRODUCTS_DIR}/\${PRODUCT_NAME}.app/GoogleService-Info.plist\\"\\nif [ -f \\"\$SRC\\" ]; then\\n  cp \\"\$SRC\\" \\"\$DST\\"\\nelse\\n  echo \\"warning: GoogleService-Info.plist not found at \$SRC\\"\\nfi\\n";
\t\t};
/* End PBXShellScriptBuildPhase section */''';

    content = content.replaceFirst(
      '/* End PBXShellScriptBuildPhase section */',
      phaseDef,
    );

    // 2. Wire into Runner target's buildPhases after the Resources phase.
    content = content.replaceFirst(
      RegExp(r'(97C146EC1CF9000F007C117D /\* Resources \*/,)'),
      '97C146EC1CF9000F007C117D /* Resources */,\n$phaseEntry',
    );

    file.writeAsStringSync(content);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _genGuid() {
    const chars = '0123456789ABCDEF';
    return List.generate(24, (_) => chars[_rng.nextInt(chars.length)]).join();
  }
}

class _ConfigList {
  const _ConfigList({
    required this.name,
    required this.listGuid,
    required this.guids,
  });

  final String name;
  final String listGuid;
  final Map<String, String> guids; // 'Debug'/'Release'/'Profile' -> GUID

  String? guidFor(String baseName) => guids[baseName];
}
