import 'dart:convert';

/// Infers Dart field types from a JSON object.
abstract final class JsonTypeInferrer {
  /// Parses [rawJson] and returns `[{name, type}, ...]` field descriptors
  /// ready to pass to [ModelGenerator].
  ///
  /// Accepts a JSON object (`{...}`) or a JSON array whose first element is an
  /// object (`[{...}, ...]`) — the latter is common for list-response samples.
  static List<Map<String, String>> extractFields(String rawJson) {
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

    return _fieldsFrom(obj);
  }

  static List<Map<String, String>> _fieldsFrom(Map<String, dynamic> map) =>
      map.entries
          .map((e) => {'name': _toCamel(e.key), 'type': _dartType(e.value)})
          .toList();

  /// Maps a JSON value to its closest Dart type.
  static String _dartType(dynamic value) {
    if (value == null) return 'dynamic';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is String) return 'String';
    if (value is List) {
      if (value.isEmpty) return 'List<dynamic>';
      final inner = _dartType(value.first);
      return 'List<$inner>';
    }
    if (value is Map) return 'Map<String, dynamic>';
    return 'dynamic';
  }

  /// Parses an existing generated model file and returns its field descriptors.
  ///
  /// Strips nullability (`?`) from the type so the list can be fed back into
  /// [ModelGenerator] regardless of whether it was a request or response model.
  static List<Map<String, String>> parseFieldsFromSource(String source) {
    final fields = <Map<String, String>>[];
    for (final line in source.split('\n')) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('final ') || !trimmed.endsWith(';')) continue;
      // e.g. "final String? email;" or "final List<Map<String, dynamic>> items;"
      final inner = trimmed.substring(6, trimmed.length - 1).trim();
      final lastSpace = inner.lastIndexOf(' ');
      if (lastSpace == -1) continue;
      final rawType = inner.substring(0, lastSpace).trim().replaceAll('?', '');
      final name = inner.substring(lastSpace + 1).trim();
      if (name.isNotEmpty && rawType.isNotEmpty) {
        fields.add({'name': name, 'type': rawType});
      }
    }
    return fields;
  }

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
