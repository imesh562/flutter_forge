import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:test/test.dart';

void main() {
  group('JsonTypeInferrer.extractFields', () {
    test('parses a flat JSON object', () {
      const json = '{"name": "Alice", "age": 30, "active": true}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields, hasLength(3));
      expect(
        result.fields.firstWhere((f) => f['name'] == 'name')['type'],
        'String',
      );
      expect(
        result.fields.firstWhere((f) => f['name'] == 'age')['type'],
        'int',
      );
      expect(
        result.fields.firstWhere((f) => f['name'] == 'active')['type'],
        'bool',
      );
      expect(result.nestedClasses, isEmpty);
    });

    test('parses a JSON array whose first element is an object', () {
      const json = '[{"id": 1, "score": 9.5}]';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields, hasLength(2));
      expect(
        result.fields.firstWhere((f) => f['name'] == 'id')['type'],
        'int',
      );
      expect(
        result.fields.firstWhere((f) => f['name'] == 'score')['type'],
        'double',
      );
    });

    test('infers List<String> for string arrays', () {
      const json = '{"tags": ["a", "b"]}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['type'], 'List<String>');
      expect(result.nestedClasses, isEmpty);
    });

    test('infers List<dynamic> for empty arrays', () {
      const json = '{"items": []}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['type'], 'List<dynamic>');
    });

    test('generates a nested class for object fields', () {
      const json = '{"meta": {"key": "value", "page": 1}}';
      final result = JsonTypeInferrer.extractFields(json);

      expect(result.fields.first['type'], 'Meta');
      expect(result.nestedClasses, hasLength(1));
      expect(result.nestedClasses.first.className, 'Meta');
      expect(result.nestedClasses.first.fields, hasLength(2));
      expect(
        result.nestedClasses.first.fields
            .firstWhere((f) => f['name'] == 'key')['type'],
        'String',
      );
      expect(
        result.nestedClasses.first.fields
            .firstWhere((f) => f['name'] == 'page')['type'],
        'int',
      );
    });

    test('generates nested class for array of objects and singularizes name',
        () {
      const json = '{"items": [{"id": 1, "name": "Alice"}]}';
      final result = JsonTypeInferrer.extractFields(json);

      expect(result.fields.first['type'], 'List<Item>');
      expect(result.nestedClasses, hasLength(1));
      expect(result.nestedClasses.first.className, 'Item');
    });

    test('singularizes ies -> y for array class names', () {
      const json = '{"categories": [{"id": 1}]}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['type'], 'List<Category>');
      expect(result.nestedClasses.first.className, 'Category');
    });

    test('handles deeply nested objects recursively', () {
      const json = '''
      {
        "user": {
          "id": 1,
          "address": {
            "street": "Main St",
            "city": "NYC"
          }
        }
      }
      ''';
      final result = JsonTypeInferrer.extractFields(json);

      expect(result.fields.first['type'], 'User');
      expect(result.nestedClasses, hasLength(2));

      final classNames = result.nestedClasses.map((n) => n.className).toSet();
      expect(classNames, containsAll(['User', 'Address']));

      final addressDef =
          result.nestedClasses.firstWhere((n) => n.className == 'Address');
      expect(addressDef.fields, hasLength(2));
    });

    test('deduplicates class names with numeric suffix on collision', () {
      const json = '''
      {
        "primary": {"id": 1},
        "secondary": {"id": 2}
      }
      ''';
      final result = JsonTypeInferrer.extractFields(json);
      // Both field types should be distinct class names
      final types = result.fields.map((f) => f['type']).toList();
      expect(types.toSet().length, 2);
    });

    test('infers dynamic for null values', () {
      const json = '{"value": null}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['type'], 'dynamic');
    });

    test('throws FormatException for invalid JSON', () {
      expect(
        () => JsonTypeInferrer.extractFields('{not valid'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for a plain JSON array of non-objects', () {
      expect(
        () => JsonTypeInferrer.extractFields('[1, 2, 3]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for empty array', () {
      expect(
        () => JsonTypeInferrer.extractFields('[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('converts snake_case keys to camelCase and records jsonKey', () {
      const json = '{"first_name": "Alice", "last_name": "Smith"}';
      final result = JsonTypeInferrer.extractFields(json);
      final names = result.fields.map((f) => f['name']).toSet();
      expect(names, containsAll(['firstName', 'lastName']));
      // Original key must be preserved for @JsonKey emission.
      expect(
        result.fields.firstWhere((f) => f['name'] == 'firstName')['jsonKey'],
        'first_name',
      );
      expect(
        result.fields.firstWhere((f) => f['name'] == 'lastName')['jsonKey'],
        'last_name',
      );
    });

    test('converts kebab-case keys to camelCase and records jsonKey', () {
      const json = '{"user-id": 1}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['name'], 'userId');
      expect(result.fields.first['jsonKey'], 'user-id');
    });

    test('lowercases first letter of PascalCase keys and records jsonKey', () {
      const json = '{"UserId": 1}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['name'], 'userId');
      expect(result.fields.first['jsonKey'], 'UserId');
    });

    test('camelCase keys produce no jsonKey entry', () {
      const json = '{"userId": 1, "firstName": "Alice"}';
      final result = JsonTypeInferrer.extractFields(json);
      for (final f in result.fields) {
        expect(f.containsKey('jsonKey'), isFalse);
      }
    });

    test('snake_case object key generates PascalCase class name', () {
      const json = '{"user_profile": {"bio": "hello"}}';
      final result = JsonTypeInferrer.extractFields(json);
      expect(result.fields.first['type'], 'UserProfile');
      expect(result.fields.first['jsonKey'], 'user_profile');
      expect(result.nestedClasses.first.className, 'UserProfile');
    });
  });

  group('JsonTypeInferrer.parseFieldsFromSource', () {
    test('parses non-nullable fields from request model', () {
      const source = '''
class LoginRequest {
  final String email;
  final String password;
}
''';
      final fields = JsonTypeInferrer.parseFieldsFromSource(source);
      expect(fields, hasLength(2));
      expect(fields[0], {'name': 'email', 'type': 'String'});
      expect(fields[1], {'name': 'password', 'type': 'String'});
    });

    test('strips nullable ? from response model fields', () {
      const source = '''
class LoginResponse {
  final String? token;
  final int? userId;
}
''';
      final fields = JsonTypeInferrer.parseFieldsFromSource(source);
      expect(fields[0], {'name': 'token', 'type': 'String'});
      expect(fields[1], {'name': 'userId', 'type': 'int'});
    });

    test('parses generic List field', () {
      const source = '''
class FooResponse {
  final List<String>? tags;
}
''';
      final fields = JsonTypeInferrer.parseFieldsFromSource(source);
      expect(fields.first['type'], 'List<String>');
      expect(fields.first['name'], 'tags');
    });

    test('returns empty list when no final fields exist', () {
      const source = 'class Empty {}';
      expect(JsonTypeInferrer.parseFieldsFromSource(source), isEmpty);
    });

    test('ignores non-field lines', () {
      const source = '''
class Foo {
  final String name;
  void doSomething() {}
  static const int x = 1;
}
''';
      final fields = JsonTypeInferrer.parseFieldsFromSource(source);
      expect(fields, hasLength(1));
      expect(fields.first['name'], 'name');
    });

    test('preserves @JsonKey annotation as jsonKey', () {
      const source = '''
class LoginResponse {
  @JsonKey(name: 'first_name')
  final String? firstName;
  final String? email;
}
''';
      final fields = JsonTypeInferrer.parseFieldsFromSource(source);
      expect(fields[0]['jsonKey'], 'first_name');
      expect(fields[0]['name'], 'firstName');
      expect(fields[1].containsKey('jsonKey'), isFalse);
    });
  });

  group('JsonTypeInferrer.parseNestedClassesFromSource', () {
    test('extracts nested class definitions and skips the main class', () {
      const source = '''
final class LoginResponse extends Equatable {
  final Meta? meta;
}

final class Meta extends Equatable {
  final int? page;
  final int? total;
}
''';
      final nested = JsonTypeInferrer.parseNestedClassesFromSource(
        source,
        'LoginResponse',
      );
      expect(nested, hasLength(1));
      expect(nested.first.className, 'Meta');
      expect(nested.first.fields, hasLength(2));
    });

    test('returns empty list when no nested classes exist', () {
      const source = '''
final class LoginResponse extends Equatable {
  final String? token;
}
''';
      final nested = JsonTypeInferrer.parseNestedClassesFromSource(
        source,
        'LoginResponse',
      );
      expect(nested, isEmpty);
    });
  });
}
