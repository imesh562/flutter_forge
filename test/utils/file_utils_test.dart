import 'dart:io';

import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:test/test.dart';

void main() {
  group('FileUtils.insertBeforeClassEnd', () {
    test('inserts before the last closing brace', () {
      const source = '''
class Foo {
  int x = 1;
}
''';
      final result = FileUtils.insertBeforeClassEnd(source, '  int y = 2;\n');
      expect(result, contains('  int y = 2;'));
      expect(result.lastIndexOf('}'), greaterThan(result.indexOf('int y = 2;')));
    });

    test('handles file with no closing brace gracefully', () {
      const source = 'abstract class Foo';
      final result = FileUtils.insertBeforeClassEnd(source, '  int x;\n');
      expect(result, contains('  int x;'));
    });

    test('result always ends with a newline after }', () {
      const source = 'class Foo {}';
      final result = FileUtils.insertBeforeClassEnd(source, '  void m() {}\n');
      expect(result.trimRight(), endsWith('}'));
    });
  });

  group('FileUtils.patchFile', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('flutter_forge_test_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('reads, transforms, and writes file content', () async {
      final file = File('${tmp.path}/test.dart');
      await file.writeAsString('hello world');

      await FileUtils.patchFile(
        file.path,
        (content) => content.replaceAll('world', 'dart'),
      );

      expect(await file.readAsString(), 'hello dart');
    });

    test('writeFile creates parent directories', () async {
      final nestedPath = '${tmp.path}/a/b/c/file.dart';
      await FileUtils.writeFile(nestedPath, 'content');
      expect(File(nestedPath).existsSync(), isTrue);
    });
  });
}
