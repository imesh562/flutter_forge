import 'dart:io';

import 'package:flutter_forge/src/feature_generator/registry_manager.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late RegistryManager registry;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('registry_test_');
    registry = RegistryManager(tmp.path);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('RegistryManager CRUD', () {
    test('read returns empty map when registry does not exist', () async {
      final result = await registry.read();
      expect(result, isEmpty);
    });

    test('featureNames returns empty list when registry absent', () async {
      expect(await registry.featureNames(), isEmpty);
    });

    test('ensureFeature creates feature entry', () async {
      await registry.ensureFeature('auth');
      final names = await registry.featureNames();
      expect(names, contains('auth'));
    });

    test('addEndpoint records bloc + endpoint', () async {
      await registry.ensureFeature('auth');
      await registry.addEndpoint(
        feature: 'auth',
        endpointName: 'login',
        type: 'rest',
        blocOrCubitName: 'auth',
        blocOrCubitType: 'bloc',
      );
      final blocs = await registry.blocsForFeature('auth');
      final endpoints = await registry.endpointsForFeature('auth');
      expect(blocs, contains('auth'));
      expect(endpoints, contains('login'));
    });

    test('addEndpoint does not duplicate bloc entry', () async {
      await registry.ensureFeature('auth');
      await registry.addEndpoint(
        feature: 'auth',
        endpointName: 'login',
        type: 'rest',
        blocOrCubitName: 'auth',
        blocOrCubitType: 'bloc',
      );
      await registry.addEndpoint(
        feature: 'auth',
        endpointName: 'register',
        type: 'rest',
        blocOrCubitName: 'auth',
        blocOrCubitType: 'bloc',
      );
      final blocs = await registry.blocsForFeature('auth');
      expect(blocs.where((b) => b == 'auth').length, 1);
    });

    test('removeFeature deletes the feature entry', () async {
      await registry.ensureFeature('profile');
      await registry.removeFeature('profile');
      expect(await registry.featureNames(), isNot(contains('profile')));
    });

    test('renameFeature preserves data under new key', () async {
      await registry.ensureFeature('old');
      await registry.addEndpoint(
        feature: 'old',
        endpointName: 'getUser',
        type: 'rest',
        blocOrCubitName: 'old',
        blocOrCubitType: 'bloc',
      );
      await registry.renameFeature('old', 'newName');
      final names = await registry.featureNames();
      expect(names, contains('newName'));
      expect(names, isNot(contains('old')));
      expect(await registry.endpointsForFeature('newName'), contains('getUser'));
    });

    test('renameFeature throws when oldName absent', () async {
      expect(
        () => registry.renameFeature('ghost', 'real'),
        throwsStateError,
      );
    });
  });

  group('RegistryManager.validate', () {
    test('returns no warnings when no blocs are registered', () async {
      await registry.ensureFeature('auth');
      final warnings = await registry.validate();
      expect(warnings, isEmpty);
    });

    test('warns when bloc files are missing', () async {
      await registry.ensureFeature('auth');
      await registry.addEndpoint(
        feature: 'auth',
        endpointName: 'login',
        type: 'rest',
        blocOrCubitName: 'auth',
        blocOrCubitType: 'bloc',
      );
      // No files exist on disk → should produce warnings.
      final warnings = await registry.validate();
      expect(warnings, isNotEmpty);
      expect(warnings.any((w) => w.contains('auth_bloc.dart')), isTrue);
    });

    test('no warnings when all bloc files exist on disk', () async {
      await registry.ensureFeature('auth');
      await registry.addEndpoint(
        feature: 'auth',
        endpointName: 'login',
        type: 'rest',
        blocOrCubitName: 'auth',
        blocOrCubitType: 'bloc',
      );

      // Create the expected files.
      final dir = Directory('${tmp.path}/lib/features/auth/presentation/blocs/auth');
      await dir.create(recursive: true);
      for (final f in ['auth_bloc.dart', 'auth_event.dart', 'auth_state.dart']) {
        await File('${dir.path}/$f').writeAsString('// stub');
      }
      // Also create repository stubs.
      final domainDir =
          Directory('${tmp.path}/lib/features/auth/domain/repositories');
      await domainDir.create(recursive: true);
      await File('${domainDir.path}/auth_repository.dart').writeAsString('// stub');
      final dataDir =
          Directory('${tmp.path}/lib/features/auth/data/repositories');
      await dataDir.create(recursive: true);
      await File('${dataDir.path}/auth_repository_impl.dart')
          .writeAsString('// stub');

      final warnings = await registry.validate();
      expect(warnings, isEmpty);
    });
  });
}
