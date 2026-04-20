import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:test/test.dart';

void main() {
  group('JsonTypeInferrer.extractFields', () {
    test('parses a flat JSON object', () {
      const json = '{"name": "Alice", "age": 30, "active": true}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields, hasLength(3));
      expect(fields.firstWhere((f) => f['name'] == 'name')['type'], 'String');
      expect(fields.firstWhere((f) => f['name'] == 'age')['type'], 'int');
      expect(fields.firstWhere((f) => f['name'] == 'active')['type'], 'bool');
    });

    test('parses a JSON array whose first element is an object', () {
      const json = '[{"id": 1, "score": 9.5}]';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields, hasLength(2));
      expect(fields.firstWhere((f) => f['name'] == 'id')['type'], 'int');
      expect(fields.firstWhere((f) => f['name'] == 'score')['type'], 'double');
    });

    test('infers List<String> for string arrays', () {
      const json = '{"tags": ["a", "b"]}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields.first['type'], 'List<String>');
    });

    test('infers List<dynamic> for empty arrays', () {
      const json = '{"items": []}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields.first['type'], 'List<dynamic>');
    });

    test('infers Map<String, dynamic> for nested objects', () {
      const json = '{"meta": {"key": "value"}}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields.first['type'], 'Map<String, dynamic>');
    });

    test('infers dynamic for null values', () {
      const json = '{"value": null}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields.first['type'], 'dynamic');
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

    test('converts snake_case keys to camelCase', () {
      const json = '{"first_name": "Alice", "last_name": "Smith"}';
      final fields = JsonTypeInferrer.extractFields(json);
      final names = fields.map((f) => f['name']).toSet();
      expect(names, containsAll(['firstName', 'lastName']));
    });

    test('converts kebab-case keys to camelCase', () {
      const json = '{"user-id": 1}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields.first['name'], 'userId');
    });

    test('lowercases first letter of PascalCase keys', () {
      const json = '{"UserId": 1}';
      final fields = JsonTypeInferrer.extractFields(json);
      expect(fields.first['name'], 'userId');
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
  });
}
