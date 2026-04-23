import 'dart:io';

import 'package:flutter_forge/src/feature_generator/model_generator.dart';
import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late ModelGenerator gen;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('model_gen_test_');
    gen = ModelGenerator();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('ModelGenerator.generateRequest', () {
    test('creates a file with correct class name and nullable fields', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [
          {'name': 'email', 'type': 'String'},
          {'name': 'password', 'type': 'String'},
        ],
      );

      final file = File(
        p.join(tmp.path, 'lib/features/auth/data/models/login_request.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('final class LoginRequest'));
      // Request fields are now nullable.
      expect(content, contains('final String? email;'));
      expect(content, contains('final String? password;'));
      // Constructor params are optional (no required).
      expect(content, isNot(contains('required this.email')));
      expect(content, contains('this.email,'));
      expect(content, contains("part 'login_request.g.dart'"));
      expect(content, contains('@JsonSerializable'));
    });

    test('creates file for endpointName with multiple words', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'getUserProfile',
        fields: [],
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/user/data/models/get_user_profile_request.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('final class GetUserProfileRequest'));
    });

    test('throws StateError if file already exists and forceOverwrite is false',
        () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [],
      );

      expect(
        () => gen.generateRequest(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'auth',
          endpointName: 'login',
          fields: [],
        ),
        throwsStateError,
      );
    });

    test('overwrites file when forceOverwrite is true', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [{'name': 'email', 'type': 'String'}],
      );

      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [{'name': 'token', 'type': 'String'}],
        forceOverwrite: true,
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/data/models/login_request.dart'),
      ).readAsString();
      expect(content, contains('final String? token;'));
      expect(content, isNot(contains('final String? email;')));
    });
  });

  group('ModelGenerator.generateResponse', () {
    test('creates a response file with nullable fields', () async {
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'login',
        fields: [
          {'name': 'token', 'type': 'String'},
          {'name': 'userId', 'type': 'int'},
        ],
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/data/models/login_response.dart'),
      ).readAsString();

      expect(content, contains('final class LoginResponse extends Equatable'));
      expect(content, contains('final String? token;'));
      expect(content, contains('final int? userId;'));
      expect(content, contains('List<Object?> get props => [token, userId]'));
    });

    test('generates valid file with empty field list', () async {
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'profile',
        endpointName: 'getProfile',
        fields: [],
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/profile/data/models/get_profile_response.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('final class GetProfileResponse'));
      expect(content, contains('List<Object?> get props => []'));
    });
  });

  group('ModelGenerator — nested classes', () {
    test('request model nested class fields are nullable', () async {
      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        endpointName: 'createOrder',
        fields: [
          {'name': 'id', 'type': 'int'},
          {'name': 'address', 'type': 'Address'},
        ],
        nestedClasses: [
          const NestedClassDef(
            className: 'Address',
            fields: [
              {'name': 'street', 'type': 'String'},
              {'name': 'city', 'type': 'String'},
            ],
          ),
        ],
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/order/data/models/create_order_request.dart',
        ),
      ).readAsString();

      expect(content, contains('final class CreateOrderRequest'));
      expect(content, contains('final Address? address;'));
      expect(content, contains('final class Address'));
      // Nested request class fields are now nullable.
      expect(content, contains('final String? street;'));
      expect(content, contains('final String? city;'));
      // No required keyword.
      expect(content, isNot(contains('required this.street')));
      expect(content, contains('@JsonSerializable(explicitToJson: true)\nfinal class Address'));
    });

    test('response model includes nested class with nullable fields', () async {
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'getUser',
        fields: [
          {'name': 'id', 'type': 'int'},
          {'name': 'profile', 'type': 'Profile'},
        ],
        nestedClasses: [
          const NestedClassDef(
            className: 'Profile',
            fields: [
              {'name': 'bio', 'type': 'String'},
              {'name': 'avatarUrl', 'type': 'String'},
            ],
          ),
        ],
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/user/data/models/get_user_response.dart',
        ),
      ).readAsString();

      expect(content, contains('final class GetUserResponse extends Equatable'));
      expect(content, contains('final Profile? profile;'));
      expect(content, contains('final class Profile extends Equatable'));
      expect(content, contains('final String? bio;'));
      expect(content, contains('final String? avatarUrl;'));
      expect(content, contains('List<Object?> get props => [bio, avatarUrl]'));
    });

    test('generates all nested classes from JSON with deep nesting', () async {
      final result = JsonTypeInferrer.extractFields('''
      {
        "id": 1,
        "user": {
          "name": "Alice",
          "address": {
            "city": "NYC"
          }
        }
      }
      ''');

      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'data',
        endpointName: 'getData',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/data/data/models/get_data_response.dart',
        ),
      ).readAsString();

      expect(content, contains('final class GetDataResponse'));
      expect(content, contains('final class User'));
      expect(content, contains('final class Address'));
      expect(content, contains('final String? city;'));
    });
  });

  group('ModelGenerator — @JsonKey for non-camelCase keys', () {
    test('emits @JsonKey for snake_case JSON fields in response', () async {
      final result = JsonTypeInferrer.extractFields(
        '{"first_name": "Alice", "user_id": 1, "email": "a@b.com"}',
      );

      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'getUser',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/data/models/get_user_response.dart'),
      ).readAsString();

      expect(content, contains("@JsonKey(name: 'first_name')"));
      expect(content, contains('final String? firstName;'));
      expect(content, contains("@JsonKey(name: 'user_id')"));
      expect(content, contains('final int? userId;'));
      // camelCase key needs no annotation.
      expect(content, isNot(contains("@JsonKey(name: 'email')")));
      expect(content, contains('final String? email;'));
    });

    test('emits @JsonKey for snake_case JSON fields in request', () async {
      final result = JsonTypeInferrer.extractFields(
        '{"access_token": "tok", "refresh_token": "ref"}',
      );

      await gen.generateRequest(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        endpointName: 'refreshToken',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/auth/data/models/refresh_token_request.dart',
        ),
      ).readAsString();

      expect(content, contains("@JsonKey(name: 'access_token')"));
      expect(content, contains('final String? accessToken;'));
      expect(content, contains("@JsonKey(name: 'refresh_token')"));
      expect(content, contains('final String? refreshToken;'));
    });

    test('nested class fields also get @JsonKey when snake_case', () async {
      final result = JsonTypeInferrer.extractFields('''
      {
        "user_data": {
          "first_name": "Alice",
          "last_name": "Smith"
        }
      }
      ''');

      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        endpointName: 'fetchUser',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/user/data/models/fetch_user_response.dart',
        ),
      ).readAsString();

      expect(content, contains("@JsonKey(name: 'user_data')"));
      expect(content, contains('final UserData? userData;'));
      expect(content, contains("@JsonKey(name: 'first_name')"));
      expect(content, contains('final String? firstName;'));
    });
  });

  group('ModelGenerator — deduplication', () {
    test('reuses existing nested class via import instead of re-emitting', () async {
      // First: generate a response that defines an Address class.
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        endpointName: 'getOrder',
        fields: [{'name': 'address', 'type': 'Address'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Address',
            fields: [{'name': 'city', 'type': 'String'}],
          ),
        ],
      );

      // Second: generate another response that also needs an Address.
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        endpointName: 'createOrder',
        fields: [{'name': 'deliveryAddress', 'type': 'Address'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Address',
            fields: [{'name': 'city', 'type': 'String'}],
          ),
        ],
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/order/data/models/create_order_response.dart',
        ),
      ).readAsString();

      // Should import instead of re-declaring.
      expect(content, contains("import 'get_order_response.dart';"));
      // Should NOT contain a duplicate Address class body.
      expect(content, isNot(contains('final class Address')));
    });

    test('emits inline when same name but different fields', () async {
      // First file defines Address with {city}.
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        endpointName: 'getOrder',
        fields: [{'name': 'address', 'type': 'Address'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Address',
            fields: [{'name': 'city', 'type': 'String'}],
          ),
        ],
      );

      // Second file needs Address with {city, country} — different fields.
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        endpointName: 'createOrder',
        fields: [{'name': 'address', 'type': 'Address'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Address',
            fields: [
              {'name': 'city', 'type': 'String'},
              {'name': 'country', 'type': 'String'},
            ],
          ),
        ],
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/order/data/models/create_order_response.dart',
        ),
      ).readAsString();

      // Fields differ → emit inline, not import.
      expect(content, contains('final class Address'));
      expect(content, isNot(contains("import 'get_order_response.dart';")));
    });

    test('emits nested class when no existing file defines it', () async {
      await gen.generateResponse(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'shop',
        endpointName: 'getProduct',
        fields: [{'name': 'category', 'type': 'Category'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Category',
            fields: [{'name': 'name', 'type': 'String'}],
          ),
        ],
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/shop/data/models/get_product_response.dart',
        ),
      ).readAsString();

      // No other file defines Category, so emit it inline without extra imports.
      expect(content, contains('final class Category'));
      expect(content, isNot(contains("import 'get_")));
    });
  });
}
