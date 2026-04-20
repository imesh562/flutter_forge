import 'dart:io';

import 'package:flutter_forge/src/color_generator/color_adder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Minimal AppColorScheme fixture matching the exact sentinel indentation
// produced by ThemeGenerator._writeAppColorScheme — the indentation of each
// sentinel line matters because ColorAdder._insert replaces the full line.
// No pre-existing Color fields so tests can freely add / remove any name.
const _schemeFixture = '''
import 'package:flutter/material.dart';

final class AppColorScheme {
  const AppColorScheme({
    // forge:constructor
  });

  // forge:fields

  static const light = AppColorScheme(
    // forge:light
  );

  static const dark = AppColorScheme(
    // forge:dark
  );

  AppColorScheme copyWith({
    // forge:copyWith-params
  }) =>
      AppColorScheme(
        // forge:copyWith-body
      );

  AppColorScheme lerp(AppColorScheme other, double t) => AppColorScheme(
      // forge:lerp
    );
}
''';

void main() {
  late Directory tmp;
  late ColorAdder adder;
  late File schemeFile;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('color_adder_test_');
    adder = ColorAdder(tmp.path);

    // Write the fixture into the expected relative path.
    schemeFile = File(
      p.join(tmp.path, 'lib', 'shared', 'theme', 'app_color_scheme.dart'),
    );
    await schemeFile.parent.create(recursive: true);
    await schemeFile.writeAsString(_schemeFixture);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('ColorAdder.add', () {
    test('inserts token into all 7 sentinel sections', () async {
      await adder.add(
        name: 'cardBackground',
        lightHex: '#FFFFFF',
        darkHex: '#1E1E1E',
      );

      final content = await schemeFile.readAsString();
      expect(content, contains('required this.cardBackground,'));
      expect(content, contains('final Color cardBackground;'));
      expect(content, contains('cardBackground: Color(0xFFFFFFFF),'));
      expect(content, contains('cardBackground: Color(0xFF1E1E1E),'));
      expect(content, contains('Color? cardBackground,'));
      expect(content, contains('cardBackground: cardBackground ?? this.cardBackground,'));
      expect(content, contains('cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,'));
    });

    test('normalises 6-char hex by prepending FF', () async {
      await adder.add(
        name: 'primary',
        lightHex: 'AABBCC',
        darkHex: '#112233',
      );

      final content = await schemeFile.readAsString();
      expect(content, contains('Color(0xFFAABBCC)'));
      expect(content, contains('Color(0xFF112233)'));
    });

    test('normalises 3-char shorthand hex', () async {
      await adder.add(name: 'accent', lightHex: '#FFF', darkHex: '#000');
      final content = await schemeFile.readAsString();
      expect(content, contains('Color(0xFFFFFFFF)'));
      expect(content, contains('Color(0xFF000000)'));
    });

    test('accepts 8-char AARRGGBB hex unchanged', () async {
      await adder.add(
        name: 'overlay',
        lightHex: '80FFFFFF',
        darkHex: '80000000',
      );
      final content = await schemeFile.readAsString();
      expect(content, contains('Color(0x80FFFFFF)'));
      expect(content, contains('Color(0x80000000)'));
    });

    test('throws StateError if file does not exist', () async {
      await schemeFile.delete();
      expect(
        () => adder.add(name: 'x', lightHex: '#FFF', darkHex: '#000'),
        throwsException,
      );
    });

    test('throws StateError if color already exists', () async {
      await adder.add(name: 'primary', lightHex: '#FFF', darkHex: '#000');
      expect(
        () => adder.add(name: 'primary', lightHex: '#EEE', darkHex: '#111'),
        throwsException,
      );
    });

    test('throws ArgumentError for invalid hex length', () async {
      expect(
        () => adder.add(name: 'bad', lightHex: '#FF', darkHex: '#000'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws ArgumentError for non-camelCase color name', () async {
      expect(
        () => adder.add(
          name: 'Card_Background',
          lightHex: '#FFF',
          darkHex: '#000',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ColorAdder.list', () {
    test('returns empty list when no tokens exist', () async {
      final tokens = await adder.list();
      expect(tokens, isEmpty);
    });

    test('returns token names after adding', () async {
      await adder.add(name: 'primary', lightHex: '#FFF', darkHex: '#000');
      await adder.add(name: 'secondary', lightHex: '#EEE', darkHex: '#111');

      final tokens = await adder.list();
      expect(tokens, containsAll(['primary', 'secondary']));
    });
  });

  group('ColorAdder.remove', () {
    test('removes all occurrences of a token', () async {
      await adder.add(
        name: 'cardBackground',
        lightHex: '#FFFFFF',
        darkHex: '#1E1E1E',
      );

      await adder.remove('cardBackground');

      final content = await schemeFile.readAsString();
      expect(content, isNot(contains('cardBackground')));
    });

    test('throws StateError if token does not exist', () async {
      expect(
        () => adder.remove('nonExistent'),
        throwsException,
      );
    });
  });

  group('ColorAdder.update', () {
    setUp(() async {
      await adder.add(
        name: 'primary',
        lightHex: '#FFFFFF',
        darkHex: '#000000',
      );
    });

    test('updates light hex only', () async {
      await adder.update(name: 'primary', lightHex: '#AAAAAA');
      final content = await schemeFile.readAsString();
      expect(content, contains('Color(0xFFAAAAAA)'));
      // Dark unchanged
      expect(content, contains('Color(0xFF000000)'));
    });

    test('updates dark hex only', () async {
      await adder.update(name: 'primary', darkHex: '#222222');
      final content = await schemeFile.readAsString();
      // Light unchanged
      expect(content, contains('Color(0xFFFFFFFF)'));
      expect(content, contains('Color(0xFF222222)'));
    });

    test('throws StateError if token does not exist', () async {
      expect(
        () => adder.update(name: 'ghost', lightHex: '#FFF'),
        throwsException,
      );
    });
  });
}
