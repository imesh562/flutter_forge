import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:path/path.dart' as p;

/// Manages `codegen_registry.json` — the source of truth for all generated
/// features, BLoCs, Cubits, and endpoints.
final class RegistryManager {
  RegistryManager(this._projectPath);

  final String _projectPath;

  String get _registryPath => p.join(_projectPath, 'codegen_registry.json');

  Future<Map<String, dynamic>> read() async => FileUtils.readJson(_registryPath);

  Future<void> write(Map<String, dynamic> registry) async =>
      FileUtils.writeJson(_registryPath, registry);

  Future<List<String>> featureNames() async {
    final registry = await read();
    final features = registry['features'] as Map<String, dynamic>? ?? {};
    return features.keys.toList();
  }

  Future<List<String>> blocsForFeature(String feature) async {
    final registry = await read();
    final features = registry['features'] as Map<String, dynamic>? ?? {};
    final f = features[feature] as Map<String, dynamic>? ?? {};
    final blocs = f['blocs'] as List<dynamic>? ?? [];
    return blocs.cast<String>();
  }

  Future<List<String>> endpointsForFeature(String feature) async {
    final registry = await read();
    final features = registry['features'] as Map<String, dynamic>? ?? {};
    final f = features[feature] as Map<String, dynamic>? ?? {};
    final endpoints = f['endpoints'] as List<dynamic>? ?? [];
    return endpoints
        .cast<Map<String, dynamic>>()
        .map((e) => e['name'] as String)
        .toList();
  }

  Future<List<String>> cubitsForFeature(String feature) async {
    final registry = await read();
    final features = registry['features'] as Map<String, dynamic>? ?? {};
    final f = features[feature] as Map<String, dynamic>? ?? {};
    final cubits = f['cubits'] as List<dynamic>? ?? [];
    return cubits.cast<String>();
  }

  /// Appends a new endpoint entry; never overwrites existing data.
  Future<void> addEndpoint({
    required String feature,
    required String endpointName,
    required String type,
    required String blocOrCubitName,
    required String blocOrCubitType,
  }) async {
    final registry = await read();
    final features =
        (registry['features'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();

    final f = (features[feature] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();
    final blocs = List<String>.from(f['blocs'] as List<dynamic>? ?? []);
    final cubits = List<String>.from(f['cubits'] as List<dynamic>? ?? []);
    final endpoints =
        List<Map<String, dynamic>>.from(f['endpoints'] as List<dynamic>? ?? []);

    if (blocOrCubitType == 'bloc' && !blocs.contains(blocOrCubitName)) {
      blocs.add(blocOrCubitName);
    }
    if (blocOrCubitType == 'cubit' && !cubits.contains(blocOrCubitName)) {
      cubits.add(blocOrCubitName);
    }

    endpoints.add(<String, dynamic>{
      'name': endpointName,
      'type': type,
      'handledBy': blocOrCubitName,
      'handlerType': blocOrCubitType,
    });

    features[feature] = <String, dynamic>{
      'blocs': blocs,
      'cubits': cubits,
      'endpoints': endpoints,
    };
    registry['features'] = features;
    await write(registry);
  }

  Future<void> removeFeature(String name) async {
    final registry = await read();
    final features =
        (registry['features'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();
    features.remove(name);
    registry['features'] = features;
    await write(registry);
  }

  Future<void> renameFeature(String oldName, String newName) async {
    final registry = await read();
    final features =
        (registry['features'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();
    if (!features.containsKey(oldName)) {
      throw StateError("Feature '$oldName' not found in registry.");
    }
    if (features.containsKey(newName)) {
      throw StateError("Feature '$newName' already exists in registry.");
    }
    // Preserve order by rebuilding the map.
    final updated = <String, dynamic>{};
    for (final entry in features.entries) {
      updated[entry.key == oldName ? newName : entry.key] = entry.value;
    }
    registry['features'] = updated;
    await write(registry);
  }

  /// Ensures a feature entry exists in the registry (adds it if missing).
  Future<void> ensureFeature(String feature) async {
    final registry = await read();
    final features =
        (registry['features'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();
    if (!features.containsKey(feature)) {
      features[feature] = <String, dynamic>{
        'blocs': <String>[],
        'cubits': <String>[],
        'endpoints': <Map<String, dynamic>>[],
      };
      registry['features'] = features;
      await write(registry);
    }
  }

  /// Sets the primary BLoC/Cubit for a feature and adds it to the blocs/cubits list.
  Future<void> setPrimaryBloc(String feature, String name, String type) async {
    final registry = await read();
    final features =
        (registry['features'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();
    final f = (features[feature] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();

    final blocs = List<String>.from(f['blocs'] as List<dynamic>? ?? []);
    final cubits = List<String>.from(f['cubits'] as List<dynamic>? ?? []);
    final endpoints = List<Map<String, dynamic>>.from(f['endpoints'] as List<dynamic>? ?? []);

    if (type == 'bloc' && !blocs.contains(name)) blocs.add(name);
    if (type == 'cubit' && !cubits.contains(name)) cubits.add(name);

    features[feature] = <String, dynamic>{
      'primaryBloc': <String, dynamic>{'name': name, 'type': type},
      'blocs': blocs,
      'cubits': cubits,
      'endpoints': endpoints,
    };
    registry['features'] = features;
    await write(registry);
  }

  /// Returns the primary BLoC/Cubit info for a feature, or null if not set.
  Future<Map<String, String>?> primaryBlocForFeature(String feature) async {
    final registry = await read();
    final features = registry['features'] as Map<String, dynamic>? ?? {};
    final f = features[feature] as Map<String, dynamic>? ?? {};
    final primary = f['primaryBloc'] as Map<String, dynamic>?;
    if (primary == null) return null;
    return {
      'name': primary['name'] as String,
      'type': primary['type'] as String,
    };
  }

  static Map<String, dynamic> initialRegistry() => <String, dynamic>{
        'features': <String, dynamic>{
          'auth': <String, dynamic>{
            'primaryBloc': <String, dynamic>{'name': 'auth', 'type': 'bloc'},
            'blocs': <String>['auth'],
            'cubits': <String>[],
            'endpoints': <Map<String, dynamic>>[],
          },
          'onboarding': <String, dynamic>{
            'primaryBloc': <String, dynamic>{'name': 'onboarding', 'type': 'bloc'},
            'blocs': <String>['onboarding'],
            'cubits': <String>[],
            'endpoints': <Map<String, dynamic>>[],
          },
        },
      };

  /// Validates that every feature/bloc/cubit registered in the registry still
  /// has its files on disk. Returns a list of human-readable drift warnings.
  ///
  /// Call this at the start of a wizard session so developers know immediately
  /// if the registry is out of sync with the codebase.
  Future<List<String>> validate() async {
    final warnings = <String>[];
    final registry = await read();
    final features =
        (registry['features'] as Map<String, dynamic>? ?? {}).cast<String, dynamic>();

    for (final featureEntry in features.entries) {
      final feature = featureEntry.key;
      final featureSnake = StringUtils.toSnakeCase(feature);

      final f = (featureEntry.value as Map<String, dynamic>? ?? {}).cast<String, dynamic>();

      // Check BLoC files.
      final blocs = List<String>.from(f['blocs'] as List<dynamic>? ?? []);
      for (final bloc in blocs) {
        final snake = StringUtils.toSnakeCase(bloc);
        final dir = p.join(_projectPath, 'lib', 'features', feature, 'presentation', 'blocs', snake);
        for (final file in ['${snake}_bloc.dart', '${snake}_event.dart', '${snake}_state.dart']) {
          if (!File(p.join(dir, file)).existsSync()) {
            warnings.add('⚠ Registry lists BLoC "$bloc" for feature "$feature" '
                'but $file is missing from disk.');
          }
        }
      }

      // Check Cubit files.
      final cubits = List<String>.from(f['cubits'] as List<dynamic>? ?? []);
      for (final cubit in cubits) {
        final snake = StringUtils.toSnakeCase(cubit);
        final dir = p.join(_projectPath, 'lib', 'features', feature, 'presentation', 'cubits', snake);
        for (final file in ['${snake}_cubit.dart', '${snake}_state.dart']) {
          if (!File(p.join(dir, file)).existsSync()) {
            warnings.add('⚠ Registry lists Cubit "$cubit" for feature "$feature" '
                'but $file is missing from disk.');
          }
        }
      }

      // Check repository files.
      final repoAbstract = p.join(
        _projectPath,
        'lib',
        'features',
        feature,
        'domain',
        'repositories',
        '${featureSnake}_repository.dart',
      );
      final repoImpl = p.join(
        _projectPath,
        'lib',
        'features',
        feature,
        'data',
        'repositories',
        '${featureSnake}_repository_impl.dart',
      );
      if (blocs.isNotEmpty || cubits.isNotEmpty) {
        if (!File(repoAbstract).existsSync()) {
          warnings.add('⚠ Feature "$feature" has BLoCs/Cubits but '
              '${featureSnake}_repository.dart is missing from disk.');
        }
        if (!File(repoImpl).existsSync()) {
          warnings.add('⚠ Feature "$feature" has BLoCs/Cubits but '
              '${featureSnake}_repository_impl.dart is missing from disk.');
        }
      }
    }

    return warnings;
  }

  static bool registryExists(String projectPath) =>
      File(p.join(projectPath, 'codegen_registry.json')).existsSync();
}
