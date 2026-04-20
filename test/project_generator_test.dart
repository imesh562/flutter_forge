import 'dart:io';

import 'package:flutter_forge/src/models/flavor_config.dart';
import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/project_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

ProjectConfig _makeConfig(String outputDir) => ProjectConfig(
      projectName: 'test_app',
      appDisplayName: 'Test App',
      orgIdentifier: 'com.example',
      outputDirectory: outputDir,
      flavorSettings: [
        const FlavorSettings(
          flavor: Flavor.prod,
          bundleId: 'com.example.testapp',
          baseUrl: 'https://api.example.com',
          wsUrl: 'wss://api.example.com',
        ),
      ],
      useFirebase: false,
      useFlavors: false,
    );

void main() {
  late Directory tmp;
  final gen = const ProjectGenerator();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pg_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  group('ProjectGenerator.runWithSteps', () {
    test('executes all steps in order', () async {
      final log = <int>[];
      final config = _makeConfig(tmp.path);

      await gen.runWithSteps(config, [
        () async => log.add(1),
        () async => log.add(2),
        () async => log.add(3),
      ]);

      expect(log, [1, 2, 3]);
    });

    test('rolls back project directory when a step throws', () async {
      final config = _makeConfig(tmp.path);
      final projectDir = Directory(config.projectPath);
      await projectDir.create();

      expect(projectDir.existsSync(), isTrue);

      await expectLater(
        () => gen.runWithSteps(config, [
          () async {},
          () async => throw Exception('simulated generator failure'),
        ]),
        throwsException,
      );

      expect(
        projectDir.existsSync(),
        isFalse,
        reason: 'project directory should be deleted on failure',
      );
    });

    test('does not throw when project directory does not exist on failure',
        () async {
      final config = _makeConfig(tmp.path);
      // Do NOT create the project directory — simulate flutter create failing.

      await expectLater(
        () => gen.runWithSteps(config, [
          () async => throw Exception('flutter create failed'),
        ]),
        throwsException,
      );

      // No crash expected; directory simply did not exist.
      expect(Directory(config.projectPath).existsSync(), isFalse);
    });

    test('rethrows the original exception after rollback', () async {
      final config = _makeConfig(tmp.path);
      await Directory(config.projectPath).create();

      final original = Exception('specific error');

      final caught = await gen
          .runWithSteps(config, [() async => throw original])
          .then<Exception?>((_) => null)
          .catchError((dynamic e) => e as Exception);

      expect(caught, same(original));
    });

    test('partial steps before failure are not rolled back', () async {
      // Steps before the failing one may have created files outside the
      // project directory — rollback only removes the project directory.
      final config = _makeConfig(tmp.path);
      await Directory(config.projectPath).create();

      final sideEffectFile = File(p.join(tmp.path, 'side_effect.txt'));

      await expectLater(
        () => gen.runWithSteps(config, [
          () async => sideEffectFile.writeAsStringSync('created'),
          () async => throw Exception('boom'),
        ]),
        throwsException,
      );

      // Side-effect file is outside project dir, so it survives rollback.
      expect(sideEffectFile.existsSync(), isTrue);
      // Project directory is cleaned up.
      expect(Directory(config.projectPath).existsSync(), isFalse);
    });
  });
}
