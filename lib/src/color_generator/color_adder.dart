import 'dart:io';

/// Adds a new semantic color token to an existing project's [AppColorScheme].
///
/// The generated [AppColorScheme] file contains `// forge:<section>` sentinel
/// comments that act as stable insertion points. This class finds each sentinel
/// and inserts the correct Dart snippet before it.
///
/// Sections targeted:
///   - `forge:constructor`   — `required this.<name>,`
///   - `forge:fields`        — `final Color <name>;`
///   - `forge:light`         — `<name>: Color(0x<lightHex>),`
///   - `forge:dark`          — `<name>: Color(0x<darkHex>),`
///   - `forge:copyWith-params` — `Color? <name>,`
///   - `forge:copyWith-body`   — `<name>: <name> ?? this.<name>,`
///   - `forge:lerp`            — `<name>: Color.lerp(<name>, other.<name>, t)!,`
final class ColorAdder {
  const ColorAdder(this.projectPath);

  final String projectPath;

  static const _schemeRelPath = 'lib/shared/theme/app_color_scheme.dart';

  Future<void> add({
    required String name,
    required String lightHex,
    required String darkHex,
  }) async {
    final file = File('$projectPath/$_schemeRelPath');
    if (!file.existsSync()) {
      throw StateError(
        'app_color_scheme.dart not found.\n'
        'Expected: ${file.path}\n'
        'Make sure you are running this from a flutter_forge project root.',
      );
    }

    _validateName(name);
    final light = _normalizeHex(lightHex);
    final dark = _normalizeHex(darkHex);

    var content = await file.readAsString();

    if (_alreadyContains(content, name)) {
      throw StateError("Color '$name' already exists in AppColorScheme.");
    }

    content = _insert(content, '// forge:constructor',
        '    required this.$name,\n');

    content = _insert(content, '// forge:fields',
        '  final Color $name;\n');

    content = _insert(content, '// forge:light',
        '    $name: Color(0x$light),\n');

    content = _insert(content, '// forge:dark',
        '    $name: Color(0x$dark),\n');

    content = _insert(content, '// forge:copyWith-params',
        '    Color? $name,\n');

    content = _insert(content, '// forge:copyWith-body',
        '        $name: $name ?? this.$name,\n');

    content = _insert(content, '// forge:lerp',
        '      $name: Color.lerp($name, other.$name, t)!,\n');

    await file.writeAsString(content);
  }

  /// Updates the hex value of an existing token.
  ///
  /// Pass [lightHex] and/or [darkHex] — omit either to leave it unchanged.
  Future<void> update({
    required String name,
    String? lightHex,
    String? darkHex,
  }) async {
    final file = File('$projectPath/$_schemeRelPath');
    if (!file.existsSync()) {
      throw StateError('app_color_scheme.dart not found at ${file.path}');
    }

    var content = await file.readAsString();

    if (!_alreadyContains(content, name)) {
      throw StateError(
        "Color '$name' not found in AppColorScheme. "
        "Run 'flutter_forge_color list' to see available tokens.",
      );
    }

    if (lightHex == null && darkHex == null) {
      throw ArgumentError('Provide at least one of --light or --dark.');
    }

    final tokenPattern = RegExp(
      r'    ' + RegExp.escape(name) + r': Color\(0x[0-9A-Fa-f]{8}\),',
    );

    if (lightHex != null) {
      final light = _normalizeHex(lightHex);
      // Only replace inside the light block (before the forge:light sentinel).
      final sentinel = '// forge:light';
      final splitAt = content.indexOf(sentinel);
      if (splitAt == -1) throw StateError('// forge:light sentinel not found.');
      final head = content.substring(0, splitAt);
      final tail = content.substring(splitAt);
      final updated = head.replaceFirst(
        tokenPattern,
        '    $name: Color(0x$light),',
      );
      if (updated == head) {
        throw StateError("Token '$name' not found in the light block.");
      }
      content = updated + tail;
    }

    if (darkHex != null) {
      final dark = _normalizeHex(darkHex);
      // Only replace inside the dark block (between static const dark and forge:dark).
      final darkStart = content.indexOf('  static const dark');
      final sentinel = '// forge:dark';
      final splitAt = content.indexOf(sentinel);
      if (darkStart == -1 || splitAt == -1) {
        throw StateError('// forge:dark sentinel not found.');
      }
      final head = content.substring(0, darkStart);
      final mid = content.substring(darkStart, splitAt);
      final tail = content.substring(splitAt);
      final updated = mid.replaceFirst(
        tokenPattern,
        '    $name: Color(0x$dark),',
      );
      if (updated == mid) {
        throw StateError("Token '$name' not found in the dark block.");
      }
      content = head + updated + tail;
    }

    await file.writeAsString(content);
  }

  Future<void> remove(String name) async {
    final file = File('$projectPath/$_schemeRelPath');
    if (!file.existsSync()) {
      throw StateError('app_color_scheme.dart not found at ${file.path}');
    }

    var content = await file.readAsString();

    if (!_alreadyContains(content, name)) {
      throw StateError("Color '$name' not found in AppColorScheme.");
    }

    // Remove each line that references this token (field, constructor,
    // light/dark values, copyWith param, copyWith body, lerp).
    final n = RegExp.escape(name);
    final patterns = [
      RegExp('    required this\\.$n,\\n'),
      RegExp('  final Color $n;\\n'),
      RegExp('    $n: Color\\(0x[0-9A-Fa-f]{8}\\),\\n'),
      RegExp('    Color\\? $n,\\n'),
      RegExp('        $n: $n \\?\\? this\\.$n,\\n'),
      RegExp('      $n: Color\\.lerp\\($n, other\\.$n, t\\)!,\\n'),
    ];

    for (final pattern in patterns) {
      content = content.replaceFirst(pattern, '');
    }

    await file.writeAsString(content);
  }

  Future<List<String>> list() async {
    final file = File('$projectPath/$_schemeRelPath');
    if (!file.existsSync()) {
      throw StateError('app_color_scheme.dart not found at ${file.path}');
    }

    final content = await file.readAsString();
    final matches = RegExp(r'  final Color (\w+);').allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _insert(String content, String sentinel, String insertion) {
    if (!content.contains(sentinel)) {
      throw StateError(
        'Sentinel "$sentinel" not found in app_color_scheme.dart.\n'
        'The file may have been manually edited. Re-add the sentinel comment '
        'to resume automated color management.',
      );
    }
    return content.replaceFirst(sentinel, '$insertion$sentinel');
  }

  bool _alreadyContains(String content, String name) =>
      content.contains('  final Color $name;');

  /// Normalises a hex colour string to an 8-char AARRGGBB value (no prefix).
  ///
  /// Accepts:
  ///   `#RGB`, `#RRGGBB`, `#AARRGGBB`
  ///   `RGB`,  `RRGGBB`,  `AARRGGBB`
  String _normalizeHex(String raw) {
    var hex = raw.replaceFirst('#', '').toUpperCase();

    switch (hex.length) {
      case 3:
        // #RGB → FFFFRRGGBB shorthand — expand each nibble
        hex = 'FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      case 6:
        hex = 'FF$hex';
      case 8:
        break; // already AARRGGBB
      default:
        throw ArgumentError(
          'Invalid hex color "$raw". '
          'Expected #RGB, #RRGGBB, or #AARRGGBB.',
        );
    }

    if (!RegExp(r'^[0-9A-F]{8}$').hasMatch(hex)) {
      throw ArgumentError('Hex color "$raw" contains invalid characters.');
    }

    return hex;
  }

  void _validateName(String name) {
    if (name.isEmpty) throw ArgumentError('Color name cannot be empty.');
    if (!RegExp(r'^[a-z][a-zA-Z0-9]*$').hasMatch(name)) {
      throw ArgumentError(
        'Color name "$name" must be camelCase starting with a lowercase letter.',
      );
    }
  }
}
