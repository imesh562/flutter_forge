import 'package:flutter_forge/src/utils/string_utils.dart';
import 'package:test/test.dart';

void main() {
  group('StringUtils.toPascalCase', () {
    test('converts snake_case', () {
      expect(StringUtils.toPascalCase('login_user'), 'LoginUser');
    });
    test('single word', () {
      expect(StringUtils.toPascalCase('auth'), 'Auth');
    });
    test('already PascalCase passthrough', () {
      expect(StringUtils.toPascalCase('LoginUser'), 'LoginUser');
    });
    test('empty string', () {
      expect(StringUtils.toPascalCase(''), '');
    });
  });

  group('StringUtils.toCamelCase', () {
    test('converts snake_case', () {
      expect(StringUtils.toCamelCase('login_user'), 'loginUser');
    });
    test('single word is lowercase', () {
      expect(StringUtils.toCamelCase('auth'), 'auth');
    });
    test('empty string', () {
      expect(StringUtils.toCamelCase(''), '');
    });
  });

  group('StringUtils.toSnakeCase', () {
    test('converts PascalCase', () {
      expect(StringUtils.toSnakeCase('LoginUser'), 'login_user');
    });
    test('converts camelCase', () {
      expect(StringUtils.toSnakeCase('loginUser'), 'login_user');
    });
    test('no leading underscore', () {
      expect(StringUtils.toSnakeCase('Auth'), 'auth');
    });
    test('already snake_case is unchanged', () {
      expect(StringUtils.toSnakeCase('login_user'), 'login_user');
    });
  });

  group('StringUtils.isSnakeCase', () {
    test('valid snake_case', () {
      expect(StringUtils.isSnakeCase('login_user'), isTrue);
    });
    test('rejects PascalCase', () {
      expect(StringUtils.isSnakeCase('LoginUser'), isFalse);
    });
    test('rejects leading underscore', () {
      expect(StringUtils.isSnakeCase('_auth'), isFalse);
    });
  });

  group('StringUtils.isValidBundleId', () {
    test('valid bundle id', () {
      expect(StringUtils.isValidBundleId('com.myco.myapp'), isTrue);
    });
    test('valid with flavour suffix', () {
      expect(StringUtils.isValidBundleId('com.myco.myapp.dev'), isTrue);
    });
    test('rejects single segment', () {
      expect(StringUtils.isValidBundleId('myapp'), isFalse);
    });
    test('rejects starting with digit', () {
      expect(StringUtils.isValidBundleId('1com.myco.app'), isFalse);
    });
  });

  group('StringUtils.isValidDisplayName', () {
    test('accepts a plain name', () {
      expect(StringUtils.isValidDisplayName('My App'), isTrue);
    });
    test('accepts hyphens, underscores, and periods', () {
      expect(StringUtils.isValidDisplayName('My-App_2.0'), isTrue);
    });
    test('accepts unicode letters', () {
      expect(StringUtils.isValidDisplayName('日本語アプリ'), isTrue);
    });
    test('rejects a colon (breaks pubspec.yaml)', () {
      expect(StringUtils.isValidDisplayName('My App: Pro'), isFalse);
    });
    test('rejects a double quote (breaks XML attributes)', () {
      expect(StringUtils.isValidDisplayName('My "Cool" App'), isFalse);
    });
    test('rejects a single quote (breaks the Dart string literal)', () {
      expect(StringUtils.isValidDisplayName("My App's"), isFalse);
    });
    test('rejects a slash (breaks the vscode run-config file name)', () {
      expect(StringUtils.isValidDisplayName('My/App'), isFalse);
    });
    test('rejects an empty string', () {
      expect(StringUtils.isValidDisplayName(''), isFalse);
    });
  });

  group('StringUtils round-trip', () {
    test('PascalCase → snake → PascalCase', () {
      const original = 'GetUserProfile';
      final snake = StringUtils.toSnakeCase(original);
      expect(StringUtils.toPascalCase(snake), original);
    });

    test('snake_case → Pascal → snake_case', () {
      const original = 'get_user_profile';
      final pascal = StringUtils.toPascalCase(original);
      expect(StringUtils.toSnakeCase(pascal), original);
    });
  });
}
