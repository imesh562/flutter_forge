import 'dart:io';

import 'package:flutter_forge/src/feature_generator/entity_generator.dart';
import 'package:flutter_forge/src/utils/json_type_inferrer.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late EntityGenerator gen;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('entity_gen_test_');
    gen = EntityGenerator();
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('EntityGenerator.generate', () {
    test('creates entity file with Equatable, nullable fields, no JSON', () async {
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        entityName: 'User',
        fields: [
          {'name': 'id', 'type': 'int'},
          {'name': 'email', 'type': 'String'},
        ],
      );

      final file = File(
        p.join(tmp.path, 'lib/features/auth/domain/entities/user.dart'),
      );
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      expect(content, contains("import 'package:equatable/equatable.dart'"));
      expect(content, contains('final class User extends Equatable'));
      expect(content, contains('final int? id;'));
      expect(content, contains('final String? email;'));
      expect(content, contains('List<Object?> get props => [id, email]'));
      // Must NOT contain any JSON annotations.
      expect(content, isNot(contains('@JsonSerializable')));
      expect(content, isNot(contains('@JsonKey')));
      expect(content, isNot(contains('fromJson')));
      expect(content, isNot(contains('toJson')));
      expect(content, isNot(contains("part '")));
    });

    test('accepts snake_case and PascalCase entity names', () async {
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'shop',
        entityName: 'product_category',
        fields: [],
      );

      final file = File(
        p.join(
          tmp.path,
          'lib/features/shop/domain/entities/product_category.dart',
        ),
      );
      expect(file.existsSync(), isTrue);
      expect(
        await file.readAsString(),
        contains('final class ProductCategory extends Equatable'),
      );
    });

    test('throws StateError if file exists and forceOverwrite is false',
        () async {
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        entityName: 'User',
        fields: [],
      );

      expect(
        () => gen.generate(
          projectPath: tmp.path,
          pkg: 'my_app',
          feature: 'auth',
          entityName: 'User',
          fields: [],
        ),
        throwsStateError,
      );
    });

    test('overwrites when forceOverwrite is true', () async {
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        entityName: 'User',
        fields: [{'name': 'email', 'type': 'String'}],
      );

      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'auth',
        entityName: 'User',
        fields: [{'name': 'id', 'type': 'int'}],
        forceOverwrite: true,
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/auth/domain/entities/user.dart'),
      ).readAsString();
      expect(content, contains('final int? id;'));
      expect(content, isNot(contains('final String? email;')));
    });
  });

  group('EntityGenerator — nested classes from JSON', () {
    test('nested classes have no JSON annotations', () async {
      final result = JsonTypeInferrer.extractFields('''
      {
        "id": 1,
        "address": {
          "street": "Main St",
          "city": "NYC"
        }
      }
      ''');

      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        entityName: 'Order',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/order/domain/entities/order.dart'),
      ).readAsString();

      expect(content, contains('final class Order extends Equatable'));
      expect(content, contains('final Address? address;'));
      expect(content, contains('final class Address extends Equatable'));
      expect(content, contains('final String? street;'));
      expect(content, contains('final String? city;'));
      // No JSON anywhere.
      expect(content, isNot(contains('@JsonKey')));
      expect(content, isNot(contains('@JsonSerializable')));
    });

    test('snake_case JSON field names produce camelCase fields with no @JsonKey',
        () async {
      final result = JsonTypeInferrer.extractFields(
        '{"first_name": "Alice", "last_name": "Smith"}',
      );

      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'user',
        entityName: 'UserProfile',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/user/domain/entities/user_profile.dart',
        ),
      ).readAsString();

      // camelCase field names.
      expect(content, contains('final String? firstName;'));
      expect(content, contains('final String? lastName;'));
      // No @JsonKey — entities are annotation-free.
      expect(content, isNot(contains('@JsonKey')));
    });

    test('array of objects produces List<T> and nested class', () async {
      final result = JsonTypeInferrer.extractFields('''
      {
        "items": [{ "name": "Widget", "price": 9.99 }]
      }
      ''');

      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'cart',
        entityName: 'Cart',
        fields: result.fields,
        nestedClasses: result.nestedClasses,
      );

      final content = await File(
        p.join(tmp.path, 'lib/features/cart/domain/entities/cart.dart'),
      ).readAsString();

      expect(content, contains('final List<Item>? items;'));
      expect(content, contains('final class Item extends Equatable'));
      expect(content, contains('final String? name;'));
      expect(content, contains('final double? price;'));
    });
  });

  group('EntityGenerator — deduplication', () {
    test('reuses existing entity class via import (same name + same fields)',
        () async {
      // First entity defines Address.
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        entityName: 'Order',
        fields: [{'name': 'address', 'type': 'Address'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Address',
            fields: [{'name': 'city', 'type': 'String'}],
          ),
        ],
      );

      // Second entity needs the same Address.
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'order',
        entityName: 'Shipment',
        fields: [{'name': 'destination', 'type': 'Address'}],
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
          'lib/features/order/domain/entities/shipment.dart',
        ),
      ).readAsString();

      expect(content, contains("import 'order.dart';"));
      expect(content, isNot(contains('final class Address')));
    });

    test('emits inline when same name but different fields', () async {
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'shop',
        entityName: 'Product',
        fields: [{'name': 'tag', 'type': 'Tag'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Tag',
            fields: [{'name': 'label', 'type': 'String'}],
          ),
        ],
      );

      // Same class name, different fields.
      await gen.generate(
        projectPath: tmp.path,
        pkg: 'my_app',
        feature: 'shop',
        entityName: 'Category',
        fields: [{'name': 'tag', 'type': 'Tag'}],
        nestedClasses: [
          const NestedClassDef(
            className: 'Tag',
            fields: [
              {'name': 'label', 'type': 'String'},
              {'name': 'color', 'type': 'String'},
            ],
          ),
        ],
      );

      final content = await File(
        p.join(
          tmp.path,
          'lib/features/shop/domain/entities/category.dart',
        ),
      ).readAsString();

      expect(content, contains('final class Tag'));
      expect(content, isNot(contains("import 'product.dart';")));
    });
  });
}
