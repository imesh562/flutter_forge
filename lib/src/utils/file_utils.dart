import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

abstract final class FileUtils {
  /// Writes [content] to [filePath], creating parent directories as needed.
  static Future<void> writeFile(String filePath, String content) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Creates [dirPath] and places a `.gitkeep` so git tracks empty directories.
  static Future<void> ensureDir(String dirPath) async {
    await Directory(dirPath).create(recursive: true);
    await File(p.join(dirPath, '.gitkeep')).writeAsString('');
  }

  /// Reads [filePath], applies [transform], then writes the result back.
  static Future<void> patchFile(
    String filePath,
    String Function(String content) transform,
  ) async {
    final file = File(filePath);
    final original = await file.readAsString();
    await file.writeAsString(transform(original));
  }

  /// Appends [content] to [filePath].
  static Future<void> appendToFile(String filePath, String content) async {
    await File(filePath).writeAsString(content, mode: FileMode.append);
  }

  static Future<void> deleteIfExists(String filePath) async {
    final file = File(filePath);
    if (file.existsSync()) await file.delete();
  }

  /// Writes [data] as formatted JSON to [filePath].
  static Future<void> writeJson(
    String filePath,
    Map<String, dynamic> data,
  ) async {
    const encoder = JsonEncoder.withIndent('  ');
    await writeFile(filePath, '${encoder.convert(data)}\n');
  }

  /// Reads and parses a JSON file, returning an empty map if missing.
  static Future<Map<String, dynamic>> readJson(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return {};
    final raw = await file.readAsString();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected a JSON object at the top level.');
      }
      return decoded;
    } on FormatException catch (e) {
      throw FormatException(
        'Could not parse $filePath as JSON: ${e.message}\n'
        'Fix the file by hand, or delete it to start with an empty registry.',
      );
    }
  }

  /// Inserts [insertion] immediately before the closing `}` of the *first*
  /// top-level class/declaration in [content] — found by depth-counting
  /// braces from the first `{`, not by grabbing the last `}` in the whole
  /// file.
  ///
  /// Used by code generators to append methods to a class without knowing
  /// the exact line number. Depth-counting (rather than `lastIndexOf('}')`)
  /// matters because these files are meant to be hand-edited afterward: a
  /// second class, an extension, or even a trailing comment containing `}`
  /// added below the generated class would otherwise shift where the *last*
  /// brace in the file is, silently corrupting the insertion point.
  static String insertBeforeClassEnd(String content, String insertion) {
    final start = content.indexOf('{');
    if (start == -1) return '$content\n$insertion';

    var depth = 1;
    var pos = start + 1;
    while (pos < content.length && depth > 0) {
      if (content[pos] == '{') depth++;
      if (content[pos] == '}') depth--;
      pos++;
    }

    if (depth != 0) {
      // Unbalanced braces — fall back to the old whole-file behavior rather
      // than inserting at a nonsensical offset.
      final lastBrace = content.lastIndexOf('}');
      if (lastBrace == -1) return '$content\n$insertion';
      return '${content.substring(0, lastBrace)}$insertion}\n';
    }

    final classEnd = pos - 1; // index of the matching '}'
    return '${content.substring(0, classEnd)}$insertion${content.substring(classEnd)}';
  }
}
