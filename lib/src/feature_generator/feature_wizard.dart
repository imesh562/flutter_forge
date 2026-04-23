import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_forge/src/color_generator/color_adder.dart';
import 'package:flutter_forge/src/feature_generator/bloc_generator.dart';
import 'package:flutter_forge/src/feature_generator/datasource_generator.dart';
import 'package:flutter_forge/src/feature_generator/entity_generator.dart';
import 'package:flutter_forge/src/feature_generator/mock_api_manager.dart';
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
  late final _mockApiManager = MockApiManager(_projectPath);
  final _modelGen = ModelGenerator();
  final _entityGen = EntityGenerator();
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

    try {
      while (true) {
        final mode = await _promptChoice(
          'What would you like to generate?',
          options: [
            'Endpoints',
            'Entities',
            'BLoC / Cubit',
            'UI components',
            'Feature management',
            'Color tokens',
            'Mock API',
            'Exit',
          ],
        );

        switch (mode) {
          case 0:
            await _runEndpointMenuFlow();
          case 1:
            await _runEntityMenuFlow();
          case 2:
            await _runBlocCubitMenuFlow();
          case 3:
            await _runUiMenuFlow();
          case 4:
            await _runFeatureManagementMenuFlow();
          case 5:
            await _runColorMenuFlow();
          case 6:
            await _runMockApiMenuFlow();
          case 7:
            return;
        }
      }
    } finally {
      // Cancel the stdin subscription so the process can exit cleanly.
      await _lines.cancel();
    }
  }

  // ── Top-level sub-menu flows ──────────────────────────────────────────────

  Future<void> _runEndpointMenuFlow() async {
    while (true) {
      final action = await _promptChoice(
        'Endpoints — what would you like to do?',
        options: ['Create endpoint', 'Update request / response model', 'Back'],
      );
      switch (action) {
        case 0:
          await _runEndpointFlow();
        case 1:
          await _runUpdateModelFlow();
        case 2:
          return;
      }
    }
  }

  Future<void> _runEntityMenuFlow() async {
    while (true) {
      final action = await _promptChoice(
        'Entities — what would you like to do?',
        options: ['Create entity', 'Update entity', 'Back'],
      );
      switch (action) {
        case 0:
          await _runEntityFlow();
        case 1:
          await _runUpdateEntityFlow();
        case 2:
          return;
      }
    }
  }

  Future<void> _runBlocCubitMenuFlow() async {
    while (true) {
      final action = await _promptChoice(
        'BLoC / Cubit — what would you like to do?',
        options: [
          'Create BLoC',
          'Create Cubit',
          'Add event bundle to existing BLoC',
          'Add method bundle to existing Cubit',
          'Back',
        ],
      );
      switch (action) {
        case 0:
          await _runCreateBlocFlow();
        case 1:
          await _runCreateCubitFlow();
        case 2:
          await _runAddBlocBundleFlow();
        case 3:
          await _runAddCubitBundleFlow();
        case 4:
          return;
      }
    }
  }

  Future<void> _runUiMenuFlow() async {
    while (true) {
      final action = await _promptChoice(
        'UI components — what would you like to create?',
        options: ['Empty widget', 'Empty screen (page)', 'Back'],
      );
      switch (action) {
        case 0:
          await _runWidgetFlow();
        case 1:
          await _runScreenFlow();
        case 2:
          return;
      }
    }
  }

  Future<void> _runFeatureManagementMenuFlow() async {
    while (true) {
      final action = await _promptChoice(
        'Feature management — what would you like to do?',
        options: ['New feature scaffold', 'Rename feature', 'Delete feature', 'Back'],
      );
      switch (action) {
        case 0:
          await _runFeatureScaffoldFlow();
        case 1:
          await _runRenameFeatureFlow();
        case 2:
          await _runDeleteFeatureFlow();
        case 3:
          return;
      }
    }
  }

  // ── Mock API menu ─────────────────────────────────────────────────────────

  Future<void> _runMockApiMenuFlow() async {
    while (true) {
      final enabled = await _mockApiManager.isEnabled();
      final action = await _promptChoice(
        'Mock API  [currently ${enabled ? 'ENABLED' : 'DISABLED'}]',
        options: [
          '${enabled ? 'Disable' : 'Enable'} mock API',
          'Add mock response',
          'View / remove mock responses',
          'Back',
        ],
      );
      switch (action) {
        case 0:
          await _runToggleMockApiFlow(enabled);
        case 1:
          await _runAddMockResponseFlow();
        case 2:
          await _runManageMockResponsesFlow();
        case 3:
          return;
      }
    }
  }

  Future<void> _runToggleMockApiFlow(bool currentlyEnabled) async {
    await _mockApiManager.toggle();
    final nowEnabled = !currentlyEnabled;
    stdout.writeln(
      '\n✔ Mock API ${nowEnabled ? 'ENABLED' : 'DISABLED'}. '
      'Hot-restart the app to apply.',
    );
  }

  Future<void> _runAddMockResponseFlow() async {
    final methodIndex = await _promptChoice(
      'HTTP method',
      options: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    );
    final methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
    final method = methods[methodIndex];

    final path = await _prompt('Endpoint path (e.g. /auth/login)');

    stdout.writeln('  Paste the JSON response body (single line):');
    stdout.write('  ');
    final jsonBody = (await _readLine()).trim();

    try {
      await _mockApiManager.addResponse(
        method: method,
        path: path,
        jsonBody: jsonBody,
      );
      stdout.writeln('\n✔ Mock response registered for $method $path.');
      stdout.writeln('  Hot-restart the app to apply.');
    } on FormatException {
      stdout.writeln('\n✖ Invalid JSON — entry not added.');
    } on StateError catch (e) {
      stdout.writeln('\n✖ ${e.message}');
    }
  }

  Future<void> _runManageMockResponsesFlow() async {
    final keys = await _mockApiManager.listKeys();
    if (keys.isEmpty) {
      stdout.writeln('\n  No mock responses registered.');
      return;
    }

    stdout.writeln('\n  Registered mock responses:');
    for (var i = 0; i < keys.length; i++) {
      stdout.writeln('    [${i + 1}] ${keys[i]}');
    }

    stdout.writeln('  [0] Back');
    stdout.write('  Remove entry number (or 0 to go back): ');
    final raw = (await _readLine()).trim();
    final index = (int.tryParse(raw) ?? 0) - 1;
    if (index < 0 || index >= keys.length) return;

    await _mockApiManager.removeResponse(keys[index]);
    stdout.writeln('\n✔ Removed mock response for ${keys[index]}.');
    stdout.writeln('  Hot-restart the app to apply.');
  }

  // ── Endpoint flow ─────────────────────────────────────────────────────────

  Future<void> _runEndpointFlow() async {
    final features = await _registry.featureNames();
    final feature = await _resolveFeature(features);

    final endpointName = await _prompt('Endpoint name (camelCase, e.g. getUserProfile)');
    final endpointType = await _promptChoice('Endpoint type', options: ['REST', 'WebSocket']);

    var method = 'GET';
    var path = '/';
    var hasRequest = false;

    if (endpointType == 0) {
      method = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'][
          await _promptChoice('HTTP method', options: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'])];
      path = await _prompt('URL path (e.g. /users/:id)');
      hasRequest = await _promptChoice(
            'Does this endpoint have a request body / query params?',
            options: ['No', 'Yes'],
          ) ==
          1;
    }

    List<Map<String, String>> requestFields = [];
    List<NestedClassDef> requestNested = [];
    if (hasRequest) {
      stdout.writeln('\n── Request fields (enter empty name to stop) ──');
      (requestFields, requestNested) = await _collectFields();
    }

    stdout.writeln('\n── Response fields (enter empty name to stop) ──');
    final (responseFields, responseNested) = await _collectFields();

    final requestClass = hasRequest
        ? '${StringUtils.toPascalCase(endpointName)}Request'
        : null;
    final responseClass = '${StringUtils.toPascalCase(endpointName)}Response';

    final blocChoice = await _resolveBlocTarget(feature);

    stdout.writeln('\nGenerating...');

    if (hasRequest) {
      await _modelGen.generateRequest(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        endpointName: endpointName,
        fields: requestFields,
        nestedClasses: requestNested,
      );
    }

    await _modelGen.generateResponse(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      fields: responseFields,
      nestedClasses: responseNested,
    );

    await _datasourceGen.addMethod(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      method: method,
      path: path,
      endpointType: endpointType == 1 ? 'websocket' : 'rest',
      hasRequest: hasRequest,
    );

    await _repoGen.addMethod(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      endpointName: endpointName,
      endpointType: endpointType == 1 ? 'websocket' : 'rest',
      hasRequest: hasRequest,
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

  // ── Entity flow ───────────────────────────────────────────────────────────

  Future<void> _runEntityFlow() async {
    final features = await _registry.featureNames();
    final feature = await _resolveFeature(features);

    final rawName = await _prompt(
      'Entity name (e.g. User, OrderItem, ProductCategory)',
    );
    // Accept PascalCase, camelCase, or snake_case — normalise to PascalCase.
    final entityName = StringUtils.toPascalCase(
      StringUtils.toSnakeCase(rawName),
    );

    stdout.writeln('\n── Entity fields ──');
    final (fields, nestedClasses) = await _collectFields();

    stdout.writeln('\nGenerating...');

    try {
      await _entityGen.generate(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        entityName: entityName,
        fields: fields,
        nestedClasses: nestedClasses,
      );
      stdout.writeln(
        '\n✔ ${entityName} created at '
        'lib/features/$feature/domain/entities/'
        '${StringUtils.toSnakeCase(entityName)}.dart',
      );
    } on StateError catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  // ── Update entity flow ────────────────────────────────────────────────────

  Future<void> _runUpdateEntityFlow() async {
    final features = await _registry.featureNames();
    if (features.isEmpty) {
      stdout.writeln('No features in registry.');
      return;
    }

    final feature = await _pickExistingFeature(features, label: 'Feature');

    final entitiesDir = p.join(
      _projectPath,
      'lib/features/$feature/domain/entities',
    );
    final entityFiles = await _listEntityFiles(entitiesDir);
    if (entityFiles.isEmpty) {
      stdout.writeln(
        'No entity files found in lib/features/$feature/domain/entities/.\n'
        'Create one first with the "Entity" option.',
      );
      return;
    }

    final entityIndex = await _promptChoice(
      'Entity to update',
      options: entityFiles.map((f) => p.basenameWithoutExtension(f)).toList(),
    );
    final entityFileName = entityFiles[entityIndex];
    final entityName = StringUtils.toPascalCase(
      p.basenameWithoutExtension(entityFileName),
    );
    final filePath = p.join(entitiesDir, entityFileName);

    final source = await File(filePath).readAsString();
    final currentFields = JsonTypeInferrer.parseFieldsFromSource(source);
    final existingNested =
        JsonTypeInferrer.parseNestedClassesFromSource(source, entityName);

    stdout.writeln('\n  Current fields in $entityName:');
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
    var updatedNested = existingNested;

    switch (action) {
      case 0: // Add
        stdout.writeln('\n── New fields to add ──');
        final (newFields, newNested) = await _collectFields();
        updatedFields = [...currentFields, ...newFields];
        updatedNested = [
          ...existingNested,
          ...newNested.where(
            (n) => !existingNested.any((e) => e.className == n.className),
          ),
        ];

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
        final (replacedFields, replacedNested) = await _collectFields();
        updatedFields = replacedFields;
        updatedNested = replacedNested;

      default:
        return;
    }

    await _entityGen.generate(
      projectPath: _projectPath,
      pkg: _pkg,
      feature: feature,
      entityName: entityName,
      fields: updatedFields,
      nestedClasses: updatedNested,
      forceOverwrite: true,
    );

    stdout.writeln(
      '\n✔ $entityName updated (${updatedFields.length} field(s)).',
    );
  }

  /// Lists `.dart` filenames (basenames only) in [entitiesDir],
  /// excluding generated `.g.dart` files.
  Future<List<String>> _listEntityFiles(String entitiesDir) async {
    final dir = Directory(entitiesDir);
    if (!dir.existsSync()) return [];
    final files = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.endsWith('.dart') && !name.endsWith('.g.dart')) {
        files.add(name);
      }
    }
    files.sort();
    return files;
  }

  // ── Standalone BLoC / Cubit flows ────────────────────────────────────────

  Future<void> _runCreateBlocFlow() async {
    final features = await _registry.featureNames();
    final feature = await _resolveFeature(features);

    final blocName = await _prompt('BLoC name (snake_case, e.g. auth, user_profile)');
    if (!StringUtils.isSnakeCase(blocName)) {
      stdout.writeln('✖ BLoC name must be snake_case.');
      return;
    }

    stdout.writeln('\nGenerating BLoC...');
    try {
      await _blocGen.createBloc(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        blocName: blocName,
      );
      await _registry.setPrimaryBloc(feature, blocName, 'bloc');
      stdout.writeln(
        '\n✔ ${StringUtils.toPascalCase(blocName)}Bloc created in '
        'lib/features/$feature/presentation/',
      );
    } on StateError catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  Future<void> _runCreateCubitFlow() async {
    final features = await _registry.featureNames();
    final feature = await _resolveFeature(features);

    final cubitName = await _prompt('Cubit name (snake_case, e.g. auth, cart_summary)');
    if (!StringUtils.isSnakeCase(cubitName)) {
      stdout.writeln('✖ Cubit name must be snake_case.');
      return;
    }

    stdout.writeln('\nGenerating Cubit...');
    try {
      await _blocGen.createCubit(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        cubitName: cubitName,
      );
      await _registry.setPrimaryBloc(feature, cubitName, 'cubit');
      stdout.writeln(
        '\n✔ ${StringUtils.toPascalCase(cubitName)}Cubit created in '
        'lib/features/$feature/presentation/',
      );
    } on StateError catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  Future<void> _runAddBlocBundleFlow() async {
    final features = await _registry.featureNames();
    if (features.isEmpty) {
      stdout.writeln('No features in registry.');
      return;
    }

    final feature = await _pickExistingFeature(features, label: 'Feature');

    final blocs = await _scanBlocFiles(feature);
    if (blocs.isEmpty) {
      stdout.writeln(
        'No BLoC files found in lib/features/$feature/presentation/.\n'
        'Create one first with "Create BLoC".',
      );
      return;
    }

    final blocIndex = await _promptChoice(
      'BLoC to update',
      options: blocs.map((b) => '${StringUtils.toPascalCase(b)}Bloc').toList(),
    );
    final blocName = blocs[blocIndex];

    final actionName = await _prompt(
      'Action name (camelCase, e.g. loadProfile, submitOrder)',
    );
    final requestType = await _promptOptional(
      'Request data type (e.g. String, UserRequest) — press Enter to skip',
    );
    final responseType = await _promptOptional(
      'Success data type (e.g. UserProfile, List<Order>) — press Enter to skip',
    );

    stdout.writeln('\nAdding event bundle...');
    try {
      await _blocGen.addCustomEventToBloc(
        projectPath: _projectPath,
        feature: feature,
        blocName: blocName,
        actionName: actionName,
        requestType: requestType,
        responseType: responseType,
      );
      final pascal = StringUtils.toPascalCase(actionName);
      stdout.writeln(
        '\n✔ Bundle added: ${pascal}Started event, '
        '${pascal}Success / ${pascal}Failure states, and handler stub.',
      );
      stdout.writeln('  Fill in the TODO in the handler with the repository call.');
    } on StateError catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  Future<void> _runAddCubitBundleFlow() async {
    final features = await _registry.featureNames();
    if (features.isEmpty) {
      stdout.writeln('No features in registry.');
      return;
    }

    final feature = await _pickExistingFeature(features, label: 'Feature');

    final cubits = await _scanCubitFiles(feature);
    if (cubits.isEmpty) {
      stdout.writeln(
        'No Cubit files found in lib/features/$feature/presentation/.\n'
        'Create one first with "Create Cubit".',
      );
      return;
    }

    final cubitIndex = await _promptChoice(
      'Cubit to update',
      options: cubits.map((c) => '${StringUtils.toPascalCase(c)}Cubit').toList(),
    );
    final cubitName = cubits[cubitIndex];

    final actionName = await _prompt(
      'Method name (camelCase, e.g. loadProfile, submitOrder)',
    );
    final requestType = await _promptOptional(
      'Request parameter type (e.g. String, UserRequest) — press Enter to skip',
    );
    final responseType = await _promptOptional(
      'Success data type (e.g. UserProfile, List<Order>) — press Enter to skip',
    );

    stdout.writeln('\nAdding method bundle...');
    try {
      await _blocGen.addCustomMethodToCubit(
        projectPath: _projectPath,
        feature: feature,
        cubitName: cubitName,
        actionName: actionName,
        requestType: requestType,
        responseType: responseType,
      );
      final pascal = StringUtils.toPascalCase(actionName);
      stdout.writeln(
        '\n✔ Bundle added: ${pascal}Success / ${pascal}Failure states '
        'and $actionName() method stub.',
      );
      stdout.writeln('  Fill in the TODO in the method with the repository call.');
    } on StateError catch (e) {
      stdout.writeln('\n✖ $e');
    }
  }

  /// Lists snake_case BLoC names from `*_bloc.dart` files in the presentation dir.
  Future<List<String>> _scanBlocFiles(String feature) async {
    final dir = Directory(
      p.join(_projectPath, 'lib/features/$feature/presentation/blocs'),
    );
    if (!dir.existsSync()) return [];
    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (File(p.join(entity.path, '${name}_bloc.dart')).existsSync()) {
        names.add(name);
      }
    }
    names.sort();
    return names;
  }

  /// Lists snake_case Cubit names from subdirectories of `presentation/cubits/`.
  Future<List<String>> _scanCubitFiles(String feature) async {
    final dir = Directory(
      p.join(_projectPath, 'lib/features/$feature/presentation/cubits'),
    );
    if (!dir.existsSync()) return [];
    final names = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (File(p.join(entity.path, '${name}_cubit.dart')).existsSync()) {
        names.add(name);
      }
    }
    names.sort();
    return names;
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
    final blocExists = File(p.join(presentationDir, 'blocs', featureSnake, '${featureSnake}_bloc.dart')).existsSync();
    final cubitExists = File(p.join(presentationDir, 'cubits', featureSnake, '${featureSnake}_cubit.dart')).existsSync();

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
    required String? requestClass,
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
    final existingNested =
        JsonTypeInferrer.parseNestedClassesFromSource(source, className);

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
    var updatedNested = existingNested;

    switch (action) {
      case 0: // Add
        stdout.writeln('\n── New fields to add ──');
        final (newFields, newNested) = await _collectFields();
        updatedFields = [...currentFields, ...newFields];
        // Merge: keep existing nested classes, add new ones that aren't already present.
        updatedNested = [
          ...existingNested,
          ...newNested.where(
            (n) => !existingNested.any((e) => e.className == n.className),
          ),
        ];

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
        final (replacedFields, replacedNested) = await _collectFields();
        updatedFields = replacedFields;
        updatedNested = replacedNested;

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
        nestedClasses: updatedNested,
        forceOverwrite: true,
      );
    } else {
      await _modelGen.generateRequest(
        projectPath: _projectPath,
        pkg: _pkg,
        feature: feature,
        endpointName: endpointName,
        fields: updatedFields,
        nestedClasses: updatedNested,
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

  Future<(List<Map<String, String>>, List<NestedClassDef>)> _collectFields() async {
    final mode = await _promptChoice(
      'How would you like to define fields?',
      options: ['Enter manually', 'Paste JSON'],
    );
    if (mode == 1) return _collectFieldsFromJson();
    final fields = await _collectFieldsManually();
    return (fields, <NestedClassDef>[]);
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

  Future<(List<Map<String, String>>, List<NestedClassDef>)>
      _collectFieldsFromJson() async {
    stdout.writeln(
      '  Paste your JSON below. Press Enter on an empty line when done.',
    );
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
      final result = JsonTypeInferrer.extractFields(rawJson);

      stdout.writeln('\n  Detected ${result.fields.length} field(s):');
      for (final f in result.fields) {
        stdout.writeln('    ${f['type']?.padRight(24)} ${f['name']}');
      }
      if (result.nestedClasses.isNotEmpty) {
        stdout.writeln(
          '\n  Nested classes (${result.nestedClasses.length}):',
        );
        for (final n in result.nestedClasses) {
          final fieldSummary =
              n.fields.map((f) => '${f['type']} ${f['name']}').join(', ');
          stdout.writeln('    ${n.className} { $fieldSummary }');
        }
      }
      stdout.writeln('');

      stdout.write('  Use these fields? [Y/n]: ');
      final confirm = (await _readLine()).trim().toLowerCase();
      if (confirm == 'n') {
        stdout.writeln('  Falling back to manual entry.');
        final fields = await _collectFieldsManually();
        return (fields, <NestedClassDef>[]);
      }

      return (result.fields, result.nestedClasses);
    } on FormatException catch (e) {
      stdout.writeln('\n  ✖ ${e.message}');
      stdout.writeln('  Falling back to manual entry.');
      final fields = await _collectFieldsManually();
      return (fields, <NestedClassDef>[]);
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
    final subFolder = blocType == 'bloc' ? 'blocs' : 'cubits';
    final importFile = '${snake}_$blocType.dart';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$_pkg/shared/widgets/base_view.dart';
import 'package:$_pkg/features/$feature/presentation/$subFolder/$snake/$importFile';

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
    final subFolder = blocType == 'bloc' ? 'blocs' : 'cubits';
    final importFile = '${snake}_$blocType.dart';

    return '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:$_pkg/shared/widgets/base_view.dart';
import 'package:$_pkg/features/$feature/presentation/$subFolder/$snake/$importFile';

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
