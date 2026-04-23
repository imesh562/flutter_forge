import 'dart:convert';

/// A class definition discovered while recursing into a JSON object.
final class NestedClassDef {
  const NestedClassDef({required this.className, required this.fields});
  final String className;
  final List<Map<String, String>> fields;
}

/// Result of parsing a JSON sample — top-level fields plus any nested classes.
final class JsonParseResult {
  const JsonParseResult({required this.fields, required this.nestedClasses});
  final List<Map<String, String>> fields;
  final List<NestedClassDef> nestedClasses;
}

/// Infers Dart field types from a JSON object.
abstract final class JsonTypeInferrer {
  /// Parses [rawJson] and returns field descriptors plus any nested class
  /// definitions needed for strongly-typed models.
  ///
  /// Accepts a JSON object (`{...}`) or a JSON array whose first element is an
  /// object (`[{...}, ...]`) — the latter is common for list-response samples.
  static JsonParseResult extractFields(String rawJson) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson.trim());
    } on FormatException catch (e) {
      throw FormatException('Invalid JSON: ${e.message}');
    }

    final Map<String, dynamic> obj;
    if (decoded is Map<String, dynamic>) {
      obj = decoded;
    } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      obj = (decoded.first as Map).cast<String, dynamic>();
    } else {
      throw FormatException(
        'Expected a JSON object or a non-empty array of objects.',
      );
    }

    final nestedClasses = <NestedClassDef>[];
    final fields = _fieldsFrom(obj, nestedClasses);
    return JsonParseResult(fields: fields, nestedClasses: nestedClasses);
  }

  static List<Map<String, String>> _fieldsFrom(
    Map<String, dynamic> map,
    List<NestedClassDef> collector,
  ) =>
      map.entries.map((e) {
        final name = _toCamel(e.key);
        final type = _dartType(e.value, e.key, collector);
        final field = <String, String>{'name': name, 'type': type};
        // Record the original JSON key so the generator can emit
        // @JsonKey(name: '...') when it differs from the Dart field name.
        if (name != e.key) field['jsonKey'] = e.key;
        return field;
      }).toList();

  static String _dartType(
    dynamic value,
    String fieldKey,
    List<NestedClassDef> collector,
  ) {
    if (value == null) return 'dynamic';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is String) return 'String';
    if (value is List) {
      if (value.isEmpty) return 'List<dynamic>';
      final first = value.first;
      if (first is Map) {
        final className = _uniqueClassName(
          _toPascalCase(_singularize(fieldKey)),
          collector,
        );
        final fields = _fieldsFrom(first.cast<String, dynamic>(), collector);
        collector.add(NestedClassDef(className: className, fields: fields));
        return 'List<$className>';
      }
      return 'List<${_dartType(first, fieldKey, collector)}>';
    }
    if (value is Map) {
      final className = _uniqueClassName(_toPascalCase(fieldKey), collector);
      final fields = _fieldsFrom(value.cast<String, dynamic>(), collector);
      collector.add(NestedClassDef(className: className, fields: fields));
      return className;
    }
    return 'dynamic';
  }

  /// Returns [base] unchanged if not yet in [collector]; appends an
  /// incrementing number suffix otherwise to avoid collisions.
  static String _uniqueClassName(String base, List<NestedClassDef> collector) {
    if (!collector.any((c) => c.className == base)) return base;
    var i = 2;
    while (collector.any((c) => c.className == '${base}$i')) {
      i++;
    }
    return '${base}$i';
  }

  /// Converts any JSON key format to PascalCase for use as a Dart class name.
  static String _toPascalCase(String key) {
    final camel = _toCamel(key);
    if (camel.isEmpty) return camel;
    return '${camel[0].toUpperCase()}${camel.substring(1)}';
  }

  /// Naively singularizes an English word (best-effort) for class naming.
  static String _singularize(String word) {
    if (word.length <= 3) return word;
    if (word.endsWith('ies')) return '${word.substring(0, word.length - 3)}y';
    if (word.endsWith('ves')) return '${word.substring(0, word.length - 3)}f';
    if (word.endsWith('sses') ||
        word.endsWith('xes') ||
        word.endsWith('ches') ||
        word.endsWith('shes')) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Parses an existing generated model file and returns its field descriptors.
  ///
  /// Strips nullability (`?`) from the type and preserves any
  /// `@JsonKey(name: '...')` annotation on the preceding line as `jsonKey`.
  static List<Map<String, String>> parseFieldsFromSource(String source) {
    final fields = <Map<String, String>>[];
    final lines = source.split('\n');
    final jsonKeyPattern = RegExp(r"@JsonKey\(name:\s*'([^']+)'\)");
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (!trimmed.startsWith('final ') || !trimmed.endsWith(';')) continue;
      // e.g. "final String? email;" or "final List<String> tags;"
      final inner = trimmed.substring(6, trimmed.length - 1).trim();
      final lastSpace = inner.lastIndexOf(' ');
      if (lastSpace == -1) continue;
      final rawType = inner.substring(0, lastSpace).trim().replaceAll('?', '');
      final name = inner.substring(lastSpace + 1).trim();
      if (name.isEmpty || rawType.isEmpty) continue;

      final field = <String, String>{'name': name, 'type': rawType};

      // Scan backward past blank lines to find a @JsonKey annotation.
      for (var j = i - 1; j >= 0; j--) {
        final prev = lines[j].trim();
        if (prev.isEmpty) continue;
        final m = jsonKeyPattern.firstMatch(prev);
        if (m != null) field['jsonKey'] = m.group(1)!;
        break;
      }

      fields.add(field);
    }
    return fields;
  }

  /// Parses every `final class` in [source] and returns a [NestedClassDef] for
  /// each, including the main class.
  static List<NestedClassDef> parseAllClassesFromSource(String source) {
    final result = <NestedClassDef>[];
    final classPattern = RegExp(r'final class (\w+)(?:\s+extends\s+\w+)?\s*\{');
    for (final match in classPattern.allMatches(source)) {
      var depth = 1;
      var pos = match.end;
      while (pos < source.length && depth > 0) {
        if (source[pos] == '{') depth++;
        if (source[pos] == '}') depth--;
        pos++;
      }
      final classBody = source.substring(match.end, pos - 1);
      result.add(
        NestedClassDef(
          className: match.group(1)!,
          fields: parseFieldsFromSource(classBody),
        ),
      );
    }
    return result;
  }

  /// Parses nested class definitions from a previously-generated model source.
  /// Used by the update flow so existing nested classes survive field edits.
  static List<NestedClassDef> parseNestedClassesFromSource(
    String source,
    String mainClassName,
  ) =>
      parseAllClassesFromSource(source)
          .where((c) => c.className != mainClassName)
          .toList();

  /// Converts snake_case / kebab-case JSON keys to camelCase Dart identifiers.
  /// Pure camelCase / PascalCase keys are lowercased at the first letter only.
  static String _toCamel(String key) {
    // Handle snake_case and kebab-case.
    if (key.contains('_') || key.contains('-')) {
      final parts = key.split(RegExp(r'[_\-]'));
      return parts.first.toLowerCase() +
          parts
              .skip(1)
              .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
              .join();
    }
    // Already camelCase/PascalCase — just ensure first letter is lowercase.
    if (key.isEmpty) return key;
    return '${key[0].toLowerCase()}${key.substring(1)}';
  }
}
