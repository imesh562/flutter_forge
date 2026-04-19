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
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Inserts [insertion] immediately before the last `}` in [content].
  ///
  /// Used by code generators to append methods to a class without knowing
  /// the exact line number. Trims trailing whitespace after the last brace
  /// so the result always ends with a clean `}\n`.
  static String insertBeforeClassEnd(String content, String insertion) {
    final lastBrace = content.lastIndexOf('}');
    if (lastBrace == -1) return '$content\n$insertion';
    return '${content.substring(0, lastBrace)}$insertion}\n';
  }
}
