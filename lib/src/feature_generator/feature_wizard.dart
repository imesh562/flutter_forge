import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_forge/src/color_generator/color_adder.dart';
import 'package:flutter_forge/src/feature_generator/bloc_generator.dart';
import 'package:flutter_forge/src/feature_generator/datasource_generator.dart';
import 'package:flutter_forge/src/feature_generator/model_generator.dart';
import 'package:flutter_forge/src/feature_generator/registry_manager.dart';
import 'package:flutter_forge/src/feature_generator/repository_generator.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

/// Interactive wizard for Phase 4 code generation.
/// Handles four generation modes:
///   1. New endpoint (REST or WebSocket) + BLoC/Cubit wiring
///   2. New feature folder scaffold
///   3. New empty widget
///   4. New empty screen (page)
final class FeatureWizard {
  FeatureWizard(this._projectPath, this._pkg);

  final String _projectPath;
  final String _pkg;

  late final _registry = RegistryManager(_projectPath);
  late final _colorAdder = ColorAdder(_projectPath);
  final _modelGen = ModelGenerator();
  final _datasourceGen = DatasourceGenerator();
  final _repoGen = RepositoryGenerator();
  final _blocGen = BlocGenerator();

  // Async stdin reader — avoids blocking the event loop on Windows where
  // stdin.readLineSync() prevents pending stdout flushes from executing.
  final _lines = StreamIterator<String>(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );

  Future<String> _readLine() async {
    await _lines.moveNext();
    return _lines.current;
  }

  Future<void> run() async {
    _printHeader();

    // Validate registry against disk — warn about drift before any generation.
    final warnings = await _registry.validate();
    if (warnings.isNotEmpty) {
      stdout.writeln('\n⚠  Registry drift detected:');
      for (final w in warnings) {
        stdout.writeln('   $w');
      }
      stdout.writeln('');
    }

    while (true) {
      final mode = await _promptChoice(
        'What would you like to generate?',
        options: [
          'Endpoint (REST or WebSocket)',
          'New feature scaffold',
          'Empty widget',
          'Empty screen (page)',
          'Update request / response model',
          'Rename feature',
          'Delete feature',
          'Color tokens',
          'Exit',
        ],
      );

      switch (mode) {
        case 0:
          await _runEndpointFlow();
        case 1:
          await _runFeatureScaffoldFlow();
        case 2:
          await _runWidgetFlow();
        case 3:
          await _runScreenFlow();
        case 4:
          await _runUpdateModelFlow();
        case 5:
          await _runRenameFeatureFlow();
        case 6:
          await _runDeleteFeatureFlow();
        case 7:
          await _runColorMenuFlow();
        case 8:
          return;
      }
    }
  }

  // ── Endpoint flow ─────────────────────────────────────────────────────────

  Future<void> _runEndpointFlow() async {
    final features = await _registry.featureNames();
    final feature = await _resolveFeature(features);

    final endpointName = await _prompt('Endpoint name (camelCase, e.g. getUserProfile)');
    final endpointType = await _promptChoice('Endpoint type', options: ['REST', 'WebSocket']);

    var method = 'GET';
    var path = '/';

    if (endpointType == 0) {
      method = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'][
          await _promptChoice('HTTP method', options: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'])];
      path = await _prompt('URL path (e.g. /users/:id)');
    }

    stdout.writeln('\n── Request fields (enter empty name to stop) ──');
    final requestFields = await _collectFields();

    stdout.writeln('\n── Response fields (enter empty name to stop) ──');
    final responseFields = await _collectFields();

    final requestClass = '${StringUtils.toPascalCase(endpointName)}Request';
    final responseClass = '${StringUtils.toPascalCase(endpointName)}Response';

    final blocChoice = await _resolveBlocTarget(feature);

    stdout.writeln('\nGenerating...');

    await _modelGen.generateRequest(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      fields: requestFields,
    );

    await _modelGen.generateResponse(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      fields: responseFields,
    );

    await _datasourceGen.addMethod(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      method: method,
      path: path,
      endpointType: endpointType == 1 ? 'websocket' : 'rest',
    );

    await _repoGen.addMethod(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      endpointType: endpointType == 1 ? 'websocket' : 'rest',
    );

    await _applyBlocChoice(
      blocChoice: blocChoice,
      feature: feature,
      endpointName: endpointName,
      requestClass: requestClass,
      responseClass: responseClass,
      endpointType: endpointType == 1 ? 'websocket' : 'rest',
    );

    await _registry.addEndpoint(
      feature: feature,
      endpointName: endpointName,
      type: endpointType == 1 ? 'websocket' : 'rest',
      blocOrCubitName: blocChoice['name'] as String,
      blocOrCubitType: blocChoice['type'] as String,
    );

    stdout.writeln('\n✔ Generation complete.');
    stdout.writeln('  Run: dart run build_runner build --delete-conflicting-outputs');
  }

  // ── Feature scaffold flow ─────────────────────────────────────────────────

  Future<void> _runFeatureScaffoldFlow() async {
    final featureName = await _prompt('Feature name (snake_case)');
    if (!StringUtils.isSnakeCase(featureName)) {
      stdout.writeln('✖ Feature name must be snake_case.');
      return;
    }

    await _scaffoldFeatureDirs(featureName);
    await _registry.ensureFeature(featureName);

    stdout.writeln('\nGenerating datasource & repository...');
    await Future.wait([
      _datasourceGen.scaffold(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: featureName,
      ),
      _repoGen.scaffold(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: featureName,
      ),
    ]);

    // Only create BLoC/Cubit if one doesn't already exist for this feature.
    final featureSnake = StringUtils.toSnakeCase(featureName);
    final presentationDir = p.join(
      _projectPath,
      'lib/features/$featureName/presentation',
    );
    final blocExists = File(p.join(presentationDir, '${featureSnake}_bloc.dart')).existsSync();
    final cubitExists = File(p.join(presentationDir, '${featureSnake}_cubit.dart')).existsSync();

    if (blocExists || cubitExists) {
      stdout.writeln('BLoC/Cubit already exists, skipping creation.');
      final existingType = blocExists ? 'bloc' : 'cubit';
      final primary = await _registry.primaryBlocForFeature(featureName);
      if (primary == null) {
        await _registry.setPrimaryBloc(featureName, featureName, existingType);
      }
    } else {
      final blocTypeChoice = await _promptChoice(
        'State manager type for this feature?',
        options: ['BLoC', 'Cubit'],
      );
      final blocType = blocTypeChoice == 0 ? 'bloc' : 'cubit';

      stdout.writeln('Generating ${blocType == 'bloc' ? 'BLoC' : 'Cubit'}...');
      if (blocType == 'bloc') {
        await _blocGen.createBloc(
          projectPath: _projectPath,
          pkg: _pkg,
          feature: featureName,
          blocName: featureName,
        );
      } else {
        await _blocGen.createCubit(
          projectPath: _projectPath,
          pkg: _pkg,
          feature: featureName,
          cubitName: featureName,
        );
      }
      await _registry.setPrimaryBloc(featureName, featureName, blocType);
    }

    stdout.writeln('\n✔ Feature "$featureName" scaffolded.');
  }

  Future<void> _scaffoldFeatureDirs(String feature) async {
    final dirs = [
      'lib/features/$feature/presentation/pages',
      'lib/features/$feature/presentation/widgets',
      'lib/features/$feature/domain/entities',
      'lib/features/$feature/domain/repositories',
      'lib/features/$feature/domain/usecases',
      'lib/features/$feature/data/models',
      'lib/features/$feature/data/datasources',
      'lib/features/$feature/data/repositories',
    ];
    for (final dir in dirs) {
      await FileUtils.ensureDir(p.join(_projectPath, dir));
    }
  }

  // ── Widget flow ───────────────────────────────────────────────────────────

  Future<void> _runWidgetFlow() async {
    final destination = await _promptChoice(
      'Where would you like to add the widget?',
      options: [
        'Feature folder  (lib/features/<feature>/presentation/widgets/)',
        'Shared widgets  (lib/shared/widgets/)',
      ],
    );

    final String filePath;

    if (destination == 1) {
      // Shared widgets path — no feature selection needed.
      final widgetName = await _prompt('Widget class name (PascalCase, e.g. AppButton)');
      final fileName = '${StringUtils.toSnakeCase(widgetName)}.dart';
      filePath = p.join(_projectPath, 'lib/shared/widgets/$fileName');

      if (File(filePath).existsSync()) {
        stdout.writeln('✖ File already exists: $filePath');
        return;
      }

      await FileUtils.ensureDir(p.join(_projectPath, 'lib/shared/widgets'));
      await FileUtils.writeFile(
        filePath,
        '''
import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:$_pkg/shared/widgets/base_view.dart';

class $widgetName extends StatelessWidget {
  const $widgetName({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// If this widget needs a BLoC, replace the above with:
//
// class $widgetName extends StatefulWidget {
//   const $widgetName({super.key});
//
//   @override
//   State<$widgetName> createState() => _${widgetName}State();
// }
//
// class _${widgetName}State extends State<$widgetName>
//     with BaseViewMixin<YourBloc, YourState, $widgetName> {
//
//   @override
//   void onState(BuildContext context, YourState state) {}
//
//   @override
//   Widget build(BuildContext context) {
//     return const SizedBox.shrink();
//   }
// }
''',
      );
    } else {
      // Feature folder path.
      final features = await _registry.featureNames();
      final feature = await _resolveFeature(features);
      final widgetName = await _prompt('Widget class name (PascalCase, e.g. UserAvatar)');
      final fileName = '${StringUtils.toSnakeCase(widgetName)}.dart';
      filePath = p.join(
        _projectPath,
        'lib/features/$feature/presentation/widgets/$fileName',
      );

      if (File(filePath).existsSync()) {
        stdout.writeln('✖ File already exists: $filePath');
        return;
      }

      final primary = await _registry.primaryBlocForFeature(feature);
      final widgetContent = _buildWidgetContent(
        widgetName: widgetName,
        feature: feature,
        primary: primary,
      );
      await FileUtils.writeFile(filePath, widgetContent);
    }

    stdout.writeln('\n✔ Widget created: $filePath');
  }

  // ── Screen flow ───────────────────────────────────────────────────────────

  Future<void> _runScreenFlow() async {
    final features = await _registry.featureNames();
    final feature = await _resolveFeature(features);
    final pageName = await _prompt('Screen class name (PascalCase, e.g. ProfilePage)');
    final fileName = '${StringUtils.toSnakeCase(pageName)}.dart';

    final filePath = p.join(
      _projectPath,
      'lib/features/$feature/presentation/pages/$fileName',
    );

    if (File(filePath).existsSync()) {
      stdout.writeln('✖ File already exists: $filePath');
      return;
    }

    final primary = await _registry.primaryBlocForFeature(feature);
    await FileUtils.writeFile(
      filePath,
      _buildScreenContent(
        pageName: pageName,
        feature: feature,
        primary: primary,
      ),
    );

    stdout.writeln('\n✔ Screen created: $filePath');

    // ── Register the new route in app_router.dart ──────────────────────────
    final routerPath = p.join(_projectPath, 'lib/navigation/app_router.dart');
    if (File(routerPath).existsSync()) {
      // Derive identifiers.
      // e.g. "UserProfilePage" → base "UserProfile"
      final routeBase =
          pageName.endsWith('Page') ? pageName.substring(0, pageName.length - 4) : pageName;
      // camelCase const name: "userProfile"
      final routeConst = StringUtils.toCamelCase(routeBase);
      // kebab-case path:  "/user-profile"
      final routePath = '/${StringUtils.toSnakeCase(routeBase).replaceAll('_', '-')}';
      // Full import statement for the new page.
      final pageImport =
          "import 'package:$_pkg/features/$feature/presentation/pages/$fileName';";

      await FileUtils.patchFile(routerPath, (content) {
        var updated = content;

        // 1. Import — insert before `import 'route_guards.dart';`
        if (!updated.contains("/$fileName'")) {
          updated = updated.replaceFirst(
            "import 'route_guards.dart';",
            "$pageImport\nimport 'route_guards.dart';",
          );
        }

        // 2. GoRoute entry — insert before the closing `],` of the routes list.
        if (!updated.contains('AppRoutes.$routeConst')) {
          updated = updated.replaceFirst(
            '    ],\n  );',
            '      GoRoute(\n'
                '        path: AppRoutes.$routeConst,\n'
                '        builder: (context, state) => const $pageName(),\n'
                '      ),\n'
                '    ],\n  );',
          );
        }

        // 3. AppRoutes const — insert before the last closing `}`.
        if (!updated.contains("$routeConst = '")) {
          final lastBrace = updated.lastIndexOf('}');
          updated =
              '${updated.substring(0, lastBrace)}  static const $routeConst = \'$routePath\';\n}\n';
        }

        return updated;
      });

      stdout.writeln('✔ Route registered: AppRoutes.$routeConst → $routePath');
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Future<String> _resolveFeature(List<String> existingFeatures) async {
    stdout.writeln('\nKnown features:');
    for (var i = 0; i < existingFeatures.length; i++) {
      stdout.writeln('  [${i + 1}] ${existingFeatures[i]}');
    }
    stdout.writeln('  [n] Enter a new feature name');

    stdout.write('  Choose [1–${existingFeatures.length} / n]: ');
    final raw = (await _readLine()).trim();

    if (raw == 'n' || raw.isEmpty) {
      final name = await _prompt('New feature name (snake_case)');
      await _scaffoldFeatureDirs(name);
      await _registry.ensureFeature(name);
      return name;
    }

    final index = int.tryParse(raw);
    if (index != null && index >= 1 && index <= existingFeatures.length) {
      return existingFeatures[index - 1];
    }

    stdout.writeln('  Using "$raw" as a new feature name.');
    await _scaffoldFeatureDirs(raw);
    await _registry.ensureFeature(raw);
    return raw;
  }

  Future<Map<String, dynamic>> _resolveBlocTarget(String feature) async {
    final blocs = await _registry.blocsForFeature(feature);
    final cubits = await _registry.cubitsForFeature(feature);

    final options = <String>[
      'Create a new BLoC',
      'Create a new Cubit',
      ...blocs.map((b) => 'Add to BLoC: $b'),
      ...cubits.map((c) => 'Add to Cubit: $c'),
    ];

    final choice = await _promptChoice('BLoC / Cubit assignment', options: options);

    if (choice == 0) {
      final name = await _prompt('New BLoC name (snake_case)');
      await _blocGen.createBloc(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        blocName: name,
      );
      return {'name': name, 'type': 'bloc', 'action': 'new'};
    }

    if (choice == 1) {
      final name = await _prompt('New Cubit name (snake_case)');
      await _blocGen.createCubit(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        cubitName: name,
      );
      return {'name': name, 'type': 'cubit', 'action': 'new'};
    }

    const blocOffset = 2;
    final cubitOffset = blocOffset + blocs.length;

    if (choice < cubitOffset) {
      return {
        'name': blocs[choice - blocOffset],
        'type': 'bloc',
        'action': 'add',
      };
    }

    return {
      'name': cubits[choice - cubitOffset],
      'type': 'cubit',
      'action': 'add',
    };
  }

  Future<void> _applyBlocChoice({
    required Map<String, dynamic> blocChoice,
    required String feature,
    required String endpointName,
    required String requestClass,
    required String responseClass,
    required String endpointType,
  }) async {
    final name = blocChoice['name'] as String;
    final type = blocChoice['type'] as String;

    if (type == 'bloc') {
      await _blocGen.addEventToBloc(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        blocName: name,
        endpointName: endpointName,
        requestClass: requestClass,
        responseClass: responseClass,
        endpointType: endpointType,
      );
    } else {
      await _blocGen.addMethodToCubit(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        cubitName: name,
        endpointName: endpointName,
        requestClass: requestClass,
        responseClass: responseClass,
        endpointType: endpointType,
      );
    }
  }

  // ── Update model flow ─────────────────────────────────────────────────────

  Future<void> _runUpdateModelFlow() async {
    final features = await _registry.featureNames();
    if (features.isEmpty) {
      stdout.writeln('No features in registry.');
      return;
    }

    final feature = await _pickExistingFeature(features, label: 'Feature');

    final endpoints = await _registry.endpointsForFeature(feature);
    if (endpoints.isEmpty) {
      stdout.writeln('No endpoints found for "$feature". Generate an endpoint first.');
      return;
    }

    final endpointIndex = await _promptChoice(
      'Endpoint',
      options: endpoints,
    );
    final endpointName = endpoints[endpointIndex];

    final modelType = await _promptChoice(
      'Model to update',
      options: ['Request', 'Response'],
    );
    final isResponse = modelType == 1;

    final modelSnake = StringUtils.toSnakeCase(endpointName);
    final suffix = isResponse ? 'response' : 'request';
    final className =
        '${StringUtils.toPascalCase(endpointName)}${isResponse ? 'Response' : 'Request'}';
    final filePath = p.join(
      _projectPath,
      'lib/features/$feature/data/models/${modelSnake}_$suffix.dart',
    );

    final file = File(filePath);
    if (!file.existsSync()) {
      stdout.writeln('✖ Model file not found: $filePath');
      return;
    }

    final source = await file.readAsString();
    final currentFields = JsonTypeInferrer.parseFieldsFromSource(source);

    stdout.writeln('\n  Current fields in $className:');
    if (currentFields.isEmpty) {
      stdout.writeln('    (none)');
    } else {
      for (final f in currentFields) {
        stdout.writeln('    ${f['type']?.padRight(24)} ${f['name']}');
      }
    }
    stdout.writeln('');

    final action = await _promptChoice(
      'What would you like to do?',
      options: [
        'Add fields',
        'Remove a field',
        'Rename a field',
        'Replace all fields',
      ],
    );

    List<Map<String, String>> updatedFields;

    switch (action) {
      case 0: // Add
        stdout.writeln('\n── New fields to add ──');
        final newFields = await _collectFields();
        updatedFields = [...currentFields, ...newFields];

      case 1: // Remove
        if (currentFields.isEmpty) {
          stdout.writeln('No fields to remove.');
          return;
        }
        final removeIndex = await _promptChoice(
          'Field to remove',
          options: currentFields
              .map((f) => '${f['type']} ${f['name']}')
              .toList(),
        );
        updatedFields = [
          ...currentFields.sublist(0, removeIndex),
          ...currentFields.sublist(removeIndex + 1),
        ];

      case 2: // Rename
        if (currentFields.isEmpty) {
          stdout.writeln('No fields to rename.');
          return;
        }
        final renameIndex = await _promptChoice(
          'Field to rename',
          options: currentFields
              .map((f) => '${f['type']} ${f['name']}')
              .toList(),
        );
        final newFieldName = await _prompt(
          'New name for "${currentFields[renameIndex]['name']}"',
        );
        updatedFields = [
          for (var i = 0; i < currentFields.length; i++)
            if (i == renameIndex)
              {'type': currentFields[i]['type']!, 'name': newFieldName}
            else
              currentFields[i],
        ];

      case 3: // Replace all
        stdout.writeln('\n── Replacement fields ──');
        updatedFields = await _collectFields();

      default:
        return;
    }

    // Regenerate the model file with the updated field list.
    if (isResponse) {
      await _modelGen.generateResponse(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        endpointName: endpointName,
        fields: updatedFields,
        forceOverwrite: true,
      );
    } else {
      await _modelGen.generateRequest(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        endpointName: endpointName,
        fields: updatedFields,
        forceOverwrite: true,
      );
    }

    stdout.writeln('\n✔ $className updated (${updatedFields.length} field(s)).');
    stdout.writeln('  Run: dart run build_runner build --delete-conflicting-outputs');
  }

  // ── Rename feature flow ───────────────────────────────────────────────────

  Future<void> _runRenameFeatureFlow() async {
    final features = await _registry.featureNames();
    if (features.isEmpty) {
      stdout.writeln('No features in registry.');
      return;
    }

    final oldName = await _pickExistingFeature(features, label: 'Feature to rename');
    final newName = await _prompt('New feature name (snake_case)');

    if (!StringUtils.isSnakeCase(newName)) {
      stdout.writeln('✖ Feature name must be snake_case.');
      return;
    }
    if (features.contains(newName)) {
      stdout.writeln('✖ A feature named "$newName" already exists.');
      return;
    }

    final oldDir = Directory(p.join(_projectPath, 'lib/features/$oldName'));
    if (!oldDir.existsSync()) {
      stdout.writeln('✖ Feature directory not found: ${oldDir.path}');
      return;
    }

    final newDir = Directory(p.join(_projectPath, 'lib/features/$newName'));
    await oldDir.rename(newDir.path);

    final updatedFiles = await _updateImportsForRename(oldName, newName);
    await _registry.renameFeature(oldName, newName);

    stdout.writeln('\n✔ Renamed "$oldName" → "$newName".');
    if (updatedFiles > 0) {
      stdout.writeln('  Updated imports in $updatedFiles file(s).');
    }
    stdout.writeln(
      '  Review app_router.dart for any route paths that still reference "$oldName".',
    );
  }

  // ── Delete feature flow ───────────────────────────────────────────────────

  Future<void> _runDeleteFeatureFlow() async {
    final features = await _registry.featureNames();
    if (features.isEmpty) {
      stdout.writeln('No features in registry.');
      return;
    }

    final feature = await _pickExistingFeature(features, label: 'Feature to delete');
    final dependents = await _findExternalDependents(feature);

    stdout.writeln('');
    if (dependents.isNotEmpty) {
      stdout.writeln(
        '⚠ The following files import from "$feature" and will have those '
        'import lines removed:',
      );
      for (final f in dependents) {
        stdout.writeln('  $f');
      }
      stdout.writeln('');
    }

    stdout.write('  Delete feature "$feature"? This cannot be undone. [y/N]: ');
    final confirm = (await _readLine()).trim().toLowerCase();
    if (confirm != 'y') {
      stdout.writeln('  Cancelled.');
      return;
    }

    // Remove external imports first so files are not left with dangling refs.
    if (dependents.isNotEmpty) {
      await _removeImportsForFeature(feature, dependents);
    }

    // Delete the feature directory.
    final featureDir = Directory(p.join(_projectPath, 'lib/features/$feature'));
    if (featureDir.existsSync()) {
      await featureDir.delete(recursive: true);
    }

    await _registry.removeFeature(feature);

    stdout.writeln('\n✔ Feature "$feature" deleted.');
    if (dependents.isNotEmpty) {
      stdout.writeln(
        '  Import lines removed. Review the affected files above for any\n'
        '  remaining widget/route usage that the compiler will flag.',
      );
    }
  }

  // ── Import helpers ────────────────────────────────────────────────────────

  /// Returns relative paths (from project root) of all Dart files outside
  /// [feature]'s own directory that import anything from it.
  Future<List<String>> _findExternalDependents(String feature) async {
    final dependents = <String>[];
    final libDir = Directory(p.join(_projectPath, 'lib'));
    final featureDirPath = p.join(_projectPath, 'lib', 'features', feature);

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (p.isWithin(featureDirPath, entity.path)) continue;

      final content = await entity.readAsString();
      if (content.contains('package:$_pkg/features/$feature/')) {
        dependents.add(
          p.relative(entity.path, from: _projectPath),
        );
      }
    }
    return dependents;
  }

  /// Removes import lines that reference [feature] from the given files.
  Future<void> _removeImportsForFeature(
    String feature,
    List<String> relPaths,
  ) async {
    final importPattern = RegExp(
      "import 'package:$_pkg/features/$feature/[^']+';\\n?",
    );
    for (final relPath in relPaths) {
      final file = File(p.join(_projectPath, relPath));
      if (!file.existsSync()) continue;
      final updated = (await file.readAsString()).replaceAll(importPattern, '');
      await file.writeAsString(updated);
    }
  }

  /// Replaces every import path segment `features/[oldName]/` with
  /// `features/[newName]/` across all Dart files in `lib/`.
  /// Returns the number of files that were modified.
  Future<int> _updateImportsForRename(String oldName, String newName) async {
    var count = 0;
    final libDir = Directory(p.join(_projectPath, 'lib'));

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final original = await entity.readAsString();
      final updated = original.replaceAll(
        'package:$_pkg/features/$oldName/',
        'package:$_pkg/features/$newName/',
      );
      if (updated != original) {
        await entity.writeAsString(updated);
        count++;
      }
    }
    return count;
  }

  // ── Feature picker (existing only — no create option) ─────────────────────

  Future<String> _pickExistingFeature(
    List<String> features, {
    String label = 'Feature',
  }) async {
    stdout.writeln('\n$label:');
    for (var i = 0; i < features.length; i++) {
      stdout.writeln('  [${i + 1}] ${features[i]}');
    }
    while (true) {
      stdout.write('  Choose [1–${features.length}]: ');
      final raw = (await _readLine()).trim();
      final index = (int.tryParse(raw) ?? 0) - 1;
      if (index >= 0 && index < features.length) return features[index];
      stdout.writeln('  ✖ Enter a number between 1 and ${features.length}.');
    }
  }

  Future<List<Map<String, String>>> _collectFields() async {
    final mode = await _promptChoice(
      'How would you like to define fields?',
      options: ['Enter manually', 'Paste JSON'],
    );
    return mode == 1 ? _collectFieldsFromJson() : _collectFieldsManually();
  }

  Future<List<Map<String, String>>> _collectFieldsManually() async {
    final fields = <Map<String, String>>[];
    while (true) {
      stdout.write('  Field name (or press Enter to finish): ');
      final name = (await _readLine()).trim();
      if (name.isEmpty) break;

      stdout.write('  Type for "$name" (e.g. String, int, bool, double): ');
      final type = (await _readLine()).trim();
      fields.add({'name': name, 'type': type.isEmpty ? 'String' : type});
    }
    return fields;
  }

  Future<List<Map<String, String>>> _collectFieldsFromJson() async {
    stdout.writeln('  Paste your JSON below. Press Enter on an empty line when done.');
    stdout.writeln('');

    final lines = <String>[];
    while (true) {
      final line = await _readLine();
      // Stop on the first empty line after content has been entered.
      if (line.isEmpty && lines.isNotEmpty) break;
      lines.add(line);
    }

    final rawJson = lines.join('\n');

    try {
      final fields = JsonTypeInferrer.extractFields(rawJson);

      stdout.writeln('\n  Detected ${fields.length} field(s):');
      for (final f in fields) {
        stdout.writeln('    ${f['type']?.padRight(24)} ${f['name']}');
      }
      stdout.writeln('');

      stdout.write('  Use these fields? [Y/n]: ');
      final confirm = (await _readLine()).trim().toLowerCase();
      if (confirm == 'n') {
        stdout.writeln('  Falling back to manual entry.');
        return _collectFieldsManually();
      }

      return fields;
    } on FormatException catch (e) {
      stdout.writeln('\n  ✖ ${e.message}');
      stdout.writeln('  Falling back to manual entry.');
      return _collectFieldsManually();
    }
  }

  // ── Color flows ───────────────────────────────────────────────────────────

  Future<void> _runColorMenuFlow() async {
    while (true) {
      final action = await _promptChoice(
        'Color tokens — what would you like to do?',
        options: ['Add token', 'Update token', 'Remove token', 'List tokens', 'Back'],
      );

      switch (action) {
        case 0:
          await _runColorAddFlow();
        case 1:
          await _runColorUpdateFlow();
        case 2:
          await _runColorRemoveFlow();
        case 3:
          await _runColorListFlow();
        case 4:
          return;
      }
    }
  }

  Future<void> _runColorAddFlow() async {
    final name = await _prompt('Color name (camelCase, e.g. cardBackground)');
    final lightHex = await _prompt('Light hex (e.g. #FFFFFF)');
    final darkHex = await _prompt('Dark hex (e.g. #1E1E1E)');
    try {
      await _colorAdder.add(name: name, lightHex: lightHex, darkHex: darkHex);
      stdout.writeln('\n✔ Added "$name" to AppColorScheme.');
      stdout.writeln('  Access via: context.appColors.$name');
    } on Exception catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  Future<void> _runColorUpdateFlow() async {
    final name = await _prompt('Color name to update');
    stdout.writeln('  Leave blank to keep the current value.');
    final lightHex = await _promptOptional('New light hex (e.g. #FFFFFF)');
    final darkHex = await _promptOptional('New dark hex (e.g. #1E1E1E)');
    if (lightHex == null && darkHex == null) {
      stdout.writeln('  Nothing to update.');
      return;
    }
    try {
      await _colorAdder.update(name: name, lightHex: lightHex, darkHex: darkHex);
      if (lightHex != null) stdout.writeln('\n✔ Light "$name" → $lightHex');
      if (darkHex != null) stdout.writeln('✔ Dark  "$name" → $darkHex');
    } on Exception catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  Future<void> _runColorRemoveFlow() async {
    final name = await _prompt('Color name to remove');
    try {
      await _colorAdder.remove(name);
      stdout.writeln('\n✔ Removed "$name" from AppColorScheme.');
    } on Exception catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  Future<void> _runColorListFlow() async {
    try {
      final tokens = await _colorAdder.list();
      stdout.writeln('\n  AppColorScheme tokens (${tokens.length}):');
      for (final t in tokens) {
        stdout.writeln('    • $t');
      }
    } on Exception catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  // ── Template builders ─────────────────────────────────────────────────────

  String _buildWidgetContent({
    required String widgetName,
    required String feature,
    required Map<String, String>? primary,
  }) {
    if (primary == null) {
      return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$_pkg/shared/widgets/base_view.dart';

// TODO: Replace YourBloc and YourState with your actual BLoC/Cubit types.
class $widgetName extends StatefulWidget {
  const $widgetName({super.key});

  @override
  State<$widgetName> createState() => _${widgetName}State();
}

class _${widgetName}State extends State<$widgetName>
    with BaseViewMixin<YourBloc, YourState, $widgetName> {

  @override
  void onState(BuildContext context, YourState state) {}

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
''';
    }

    final blocName = primary['name']!;
    final blocType = primary['type']!;
    final pascal = StringUtils.toPascalCase(blocName);
    final snake = StringUtils.toSnakeCase(blocName);
    final classType = blocType == 'bloc' ? 'Bloc' : 'Cubit';
    final importFile = '${snake}_$blocType.dart';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$_pkg/shared/widgets/base_view.dart';
import 'package:$_pkg/features/$feature/presentation/$importFile';

class $widgetName extends StatefulWidget {
  const $widgetName({super.key});

  @override
  State<$widgetName> createState() => _${widgetName}State();
}

class _${widgetName}State extends State<$widgetName>
    with BaseViewMixin<$pascal$classType, ${pascal}State, $widgetName> {

  @override
  void onState(BuildContext context, ${pascal}State state) {}

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
''';
  }

  String _buildScreenContent({
    required String pageName,
    required String feature,
    required Map<String, String>? primary,
  }) {
    if (primary == null) {
      return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$_pkg/shared/widgets/base_view.dart';

// TODO: Replace YourBloc and YourState with your actual BLoC/Cubit types.
class $pageName extends StatefulWidget {
  const $pageName({super.key});

  @override
  State<$pageName> createState() => _${pageName}State();
}

class _${pageName}State extends State<$pageName>
    with BaseViewMixin<YourBloc, YourState, $pageName> {

  @override
  void onState(BuildContext context, YourState state) {
    // Called after loading/failure handling — safe to setState freely.
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}
''';
    }

    final blocName = primary['name']!;
    final blocType = primary['type']!;
    final pascal = StringUtils.toPascalCase(blocName);
    final snake = StringUtils.toSnakeCase(blocName);
    final classType = blocType == 'bloc' ? 'Bloc' : 'Cubit';
    final importFile = '${snake}_$blocType.dart';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$_pkg/shared/widgets/base_view.dart';
import 'package:$_pkg/features/$feature/presentation/$importFile';

class $pageName extends StatefulWidget {
  const $pageName({super.key});

  @override
  State<$pageName> createState() => _${pageName}State();
}

class _${pageName}State extends State<$pageName>
    with BaseViewMixin<$pascal$classType, ${pascal}State, $pageName> {

  @override
  void onState(BuildContext context, ${pascal}State state) {
    // Called after loading/failure handling — safe to setState freely.
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.shrink(),
    );
  }
}
''';
  }

  Future<int> _promptChoice(String label, {required List<String> options}) async {
    stdout.writeln('\n$label:');
    for (var i = 0; i < options.length; i++) {
      stdout.writeln('  [${i + 1}] ${options[i]}');
    }

    while (true) {
      stdout.write('  Choose [1–${options.length}]: ');
      final raw = (await _readLine()).trim();
      final index = (int.tryParse(raw) ?? 0) - 1;
      if (index >= 0 && index < options.length) return index;
      stdout.writeln('  ✖ Enter a number between 1 and ${options.length}.');
    }
  }

  Future<String?> _promptOptional(String label) async {
    stdout.write('  $label (press Enter to skip): ');
    final raw = (await _readLine()).trim();
    return raw.isEmpty ? null : raw;
  }

  Future<String> _prompt(String label, {String? defaultValue}) async {
    while (true) {
      final hint = defaultValue != null ? ' [$defaultValue]' : '';
      stdout.write('  $label$hint: ');
      final raw = (await _readLine()).trim();
      final value = raw.isEmpty ? (defaultValue ?? '') : raw;
      if (value.isNotEmpty) return value;
      stdout.writeln('  ✖ Cannot be empty.');
    }
  }

  void _printHeader() {
    stdout.writeln('''
╔═══════════════════════════════════════════╗
║   flutter_forge — Feature Generator       ║
╚═══════════════════════════════════════════╝
''');
  }
}
