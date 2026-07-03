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

    test('inserts into the FIRST class, not the last brace in the file, '
        'when a second class follows', () {
      const source = '''
class Foo {
  int x = 1;
}

class Bar {
  int y = 2;
}
''';
      final result = FileUtils.insertBeforeClassEnd(source, '  int z = 3;\n');

      // The new member must land inside Foo, before Foo's closing brace —
      // not after Bar's, which is the last '}' in the whole file.
      final fooEnd = result.indexOf('}');
      expect(result.indexOf('int z = 3;'), lessThan(fooEnd));
      // Bar must survive completely untouched.
      expect(result, contains('class Bar {\n  int y = 2;\n}\n'));
    });

    test('inserts into the class even when a trailing comment contains a brace', () {
      const source = '''
class Foo {
  int x = 1;
}

// example usage: someMap['key'] = {'nested': true}
''';
      final result = FileUtils.insertBeforeClassEnd(source, '  int y = 2;\n');

      final classEnd = result.indexOf('}');
      expect(result.indexOf('int y = 2;'), lessThan(classEnd));
      expect(result, contains("// example usage: someMap['key'] = {'nested': true}"));
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

  group('FileUtils.readJson', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('flutter_forge_readjson_test_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('returns an empty map when the file does not exist', () async {
      final result = await FileUtils.readJson('${tmp.path}/missing.json');
      expect(result, isEmpty);
    });

    test('parses a valid JSON object', () async {
      final path = '${tmp.path}/registry.json';
      await File(path).writeAsString('{"features": {}}');
      final result = await FileUtils.readJson(path);
      expect(result, {'features': <String, dynamic>{}});
    });

    test('throws a clear FormatException — not a raw crash — for invalid JSON',
        () async {
      final path = '${tmp.path}/registry.json';
      await File(path).writeAsString('{not valid json');

      expect(
        () => FileUtils.readJson(path),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(path),
          ),
        ),
      );
    });

    test('throws a clear FormatException when the top level is not an object',
        () async {
      final path = '${tmp.path}/registry.json';
      await File(path).writeAsString('[1, 2, 3]');

      expect(() => FileUtils.readJson(path), throwsA(isA<FormatException>()));
    });
  });
}
