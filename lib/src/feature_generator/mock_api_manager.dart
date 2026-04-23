import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads and writes `mock_config.dart` and `mock_responses.dart` in the
/// generated project's `lib/core/network/` directory.
final class MockApiManager {
  MockApiManager(this._projectPath);

  final String _projectPath;

  String get _configPath =>
      p.join(_projectPath, 'lib', 'core', 'network', 'mock_config.dart');

  String get _responsesPath =>
      p.join(_projectPath, 'lib', 'core', 'network', 'mock_responses.dart');

  static const _sentinel = '// <<MOCK_ENTRIES>>';

  // ── Toggle ────────────────────────────────────────────────────────────────

  Future<bool> isEnabled() async {
    final file = File(_configPath);
    if (!file.existsSync()) return false;
    return (await file.readAsString()).contains('kUseMockApi = true');
  }

  Future<void> toggle() async {
    final file = File(_configPath);
    if (!file.existsSync()) {
      throw StateError('mock_config.dart not found — is this a flutter_forge project?');
    }
    var content = await file.readAsString();
    if (content.contains('kUseMockApi = true')) {
      content = content.replaceFirst('kUseMockApi = true', 'kUseMockApi = false');
    } else {
      content = content.replaceFirst('kUseMockApi = false', 'kUseMockApi = true');
    }
    await file.writeAsString(content);
  }

  // ── Entries ───────────────────────────────────────────────────────────────

  /// Returns registered keys in the form ['GET /user/profile', 'POST /auth/login', ...].
  Future<List<String>> listKeys() async {
    final file = File(_responsesPath);
    if (!file.existsSync()) return [];
    final pattern = RegExp(r"^\s*'(\w+ [^']+)':");
    return (await file.readAsString())
        .split('\n')
        .map((l) => pattern.firstMatch(l)?.group(1))
        .whereType<String>()
        .toList();
  }

  /// Parses [jsonBody], converts it to a Dart literal, and inserts the entry.
  /// Throws [FormatException] if [jsonBody] is not valid JSON.
  /// Throws [StateError] if the entry already exists.
  Future<void> addResponse({
    required String method,
    required String path,
    required String jsonBody,
  }) async {
    final file = File(_responsesPath);
    if (!file.existsSync()) {
      throw StateError('mock_responses.dart not found — is this a flutter_forge project?');
    }

    final key = '${method.toUpperCase()} $path';
    final keys = await listKeys();
    if (keys.contains(key)) {
      throw StateError("Entry '$key' already exists. Remove it first.");
    }

    final decoded = json.decode(jsonBody);
    final dartLiteral = _toDartLiteral(decoded);
    final entry = "  '$key': $dartLiteral,\n$_sentinel";

    var content = await file.readAsString();
    if (!content.contains(_sentinel)) {
      throw StateError('mock_responses.dart is missing the entry sentinel.');
    }
    await file.writeAsString(content.replaceFirst(_sentinel, entry));
  }

  Future<void> removeResponse(String key) async {
    final file = File(_responsesPath);
    if (!file.existsSync()) return;
    var content = await file.readAsString();
    final lines = content.split('\n');
    lines.removeWhere((l) => l.trim().startsWith("'$key':"));
    await file.writeAsString(lines.join('\n'));
  }

  // ── Dart literal conversion ───────────────────────────────────────────────

  static String _toDartLiteral(dynamic value) {
    if (value is Map) {
      final entries = value.entries
          .map((e) => "'${_escapeString(e.key as String)}': ${_toDartLiteral(e.value)}")
          .join(', ');
      return '{$entries}';
    }
    if (value is List) {
      return '[${value.map(_toDartLiteral).join(', ')}]';
    }
    if (value is String) return "'${_escapeString(value)}'";
    if (value == null) return 'null';
    return '$value'; // num, bool
  }

  static String _escapeString(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
