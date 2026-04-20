import 'dart:io';

import 'package:dart_console/dart_console.dart';
import 'package:flutter_forge/src/color_generator/color_adder.dart';

/// flutter_forge_color — manage AppColorScheme tokens in a generated project.
///
/// Usage:
///   flutter_forge_color add             — interactive prompt
///   flutter_forge_color add <name> <lightHex> <darkHex>
///   flutter_forge_color remove <name>
///   flutter_forge_color list
///
/// Run from the root of a flutter_forge project, or pass the path as the
/// last argument.
Future<void> main(List<String> args) async {
  final console = Console();

  if (args.isNotEmpty && (args.first == '--version' || args.first == '-v')) {
    stdout.writeln('1.0.0');
    return;
  }

  if (args.isEmpty || args.first == '--help' || args.first == '-h') {
    _printHelp();
    return;
  }

  final command = args.first;
  final rest = args.skip(1).toList();

  // Optional trailing path argument — default to current directory.
  final projectPath = rest.isNotEmpty && Directory(rest.last).existsSync()
      ? rest.last
      : Directory.current.path;

  final adder = ColorAdder(projectPath);

  switch (command) {
    case 'add':
      await _runAdd(console, adder, rest);
    case 'update':
      await _runUpdate(console, adder, rest);
    case 'remove':
      await _runRemove(console, adder, rest);
    case 'list':
      await _runList(console, adder);
    default:
      stderr.writeln('✖ Unknown command "$command". Run with --help for usage.');
      exit(1);
  }
}

// ── add ───────────────────────────────────────────────────────────────────────

Future<void> _runAdd(
  Console console,
  ColorAdder adder,
  List<String> rest,
) async {
  String name;
  String lightHex;
  String darkHex;

  // Non-interactive: flutter_forge_color add cardBg FFF8F8F8 FF1E1E1E
  if (rest.length >= 3) {
    name = rest[0];
    lightHex = rest[1];
    darkHex = rest[2];
  } else {
    // Interactive mode
    console.writeLine();
    console.writeLine('  Adding a new color token to AppColorScheme');
    console.writeLine('  ──────────────────────────────────────────');
    console.writeLine();

    name = _prompt(console, '  Color name (camelCase)', example: 'cardBackground');
    lightHex = _prompt(console, '  Light hex', example: '#FFFFFF');
    darkHex = _prompt(console, '  Dark hex', example: '#1E1E1E');
    console.writeLine();
  }

  try {
    await adder.add(name: name, lightHex: lightHex, darkHex: darkHex);
    console.writeLine('  ✔ Added "$name" to AppColorScheme.');
    console.writeLine(
      '  Access it in widgets via: context.appColors.$name',
    );
  } on Exception catch (e) {
    stderr.writeln('\n  ✖ $e');
    exit(1);
  }
}

// ── update ────────────────────────────────────────────────────────────────────

Future<void> _runUpdate(
  Console console,
  ColorAdder adder,
  List<String> rest,
) async {
  String name;
  String? lightHex;
  String? darkHex;

  // Non-interactive: flutter_forge_color update cardBg --light=#FFF --dark=#111
  if (rest.isNotEmpty && !rest.first.startsWith('--')) {
    name = rest.first;
    for (final arg in rest.skip(1)) {
      if (arg.startsWith('--light=')) {
        lightHex = arg.substring('--light='.length);
      } else if (arg.startsWith('--dark=')) {
        darkHex = arg.substring('--dark='.length);
      }
    }
    if (lightHex == null && darkHex == null) {
      stderr.writeln(
        '  ✖ Provide at least one of --light=<hex> or --dark=<hex>.',
      );
      exit(1);
    }
  } else {
    // Interactive mode
    console.writeLine();
    console.writeLine('  Updating a color token in AppColorScheme');
    console.writeLine('  ────────────────────────────────────────');
    console.writeLine();

    name = _prompt(console, '  Color name to update');

    console.writeLine(
      '  Leave a hex blank to keep the current value.',
    );
    console.writeLine();

    lightHex = _promptOptional(console, '  New light hex', example: '#FFFFFF');
    darkHex = _promptOptional(console, '  New dark hex', example: '#1E1E1E');

    if (lightHex == null && darkHex == null) {
      console.writeLine('  Nothing to update.');
      return;
    }

    console.writeLine();
  }

  try {
    await adder.update(name: name, lightHex: lightHex, darkHex: darkHex);
    if (lightHex != null) console.writeLine('  ✔ Light "$name" → $lightHex');
    if (darkHex != null) console.writeLine('  ✔ Dark  "$name" → $darkHex');
  } on Exception catch (e) {
    stderr.writeln('\n  ✖ $e');
    exit(1);
  }
}

// ── remove ────────────────────────────────────────────────────────────────────

Future<void> _runRemove(
  Console console,
  ColorAdder adder,
  List<String> rest,
) async {
  final name = rest.isNotEmpty
      ? rest.first
      : _prompt(console, '  Color name to remove');

  try {
    await adder.remove(name);
    console.writeLine('  ✔ Removed "$name" from AppColorScheme.');
  } on Exception catch (e) {
    stderr.writeln('\n  ✖ $e');
    exit(1);
  }
}

// ── list ──────────────────────────────────────────────────────────────────────

Future<void> _runList(Console console, ColorAdder adder) async {
  try {
    final tokens = await adder.list();
    console.writeLine();
    console.writeLine('  AppColorScheme tokens (${tokens.length}):');
    for (final t in tokens) {
      console.writeLine('    • $t');
    }
    console.writeLine();
  } on Exception catch (e) {
    stderr.writeln('\n  ✖ $e');
    exit(1);
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

String _prompt(Console console, String label, {String? example}) {
  final hint = example != null ? ' ($example)' : '';
  console.write('  $label$hint: ');
  final value = console.readLine()?.trim() ?? '';
  if (value.isEmpty) {
    stderr.writeln('  ✖ Value cannot be empty.');
    exit(1);
  }
  return value;
}

/// Like [_prompt] but returns null when the user presses Enter.
String? _promptOptional(Console console, String label, {String? example}) {
  final hint = example != null ? ' ($example)' : '';
  console.write('  $label$hint: ');
  final value = console.readLine()?.trim() ?? '';
  return value.isEmpty ? null : value;
}

void _printHelp() {
  stdout.writeln('''
flutter_forge_color — manage AppColorScheme tokens

Commands:
  add    [name] [lightHex] [darkHex]          Add a new token (interactive if args omitted)
  update <name> [--light=<hex>] [--dark=<hex>] Update light and/or dark value of a token
  remove <name>                               Remove a token
  list                                        List all tokens

Arguments:
  name        camelCase token name        e.g. cardBackground
  lightHex    Hex color for light mode    e.g. #FFFFFF or FFFFFFFF
  darkHex     Hex color for dark mode     e.g. #1E1E1E or FF1E1E1E

Options:
  [path]      Project root (default: current directory)

Examples:
  flutter_forge_color add
  flutter_forge_color add cardBackground "#FFFFFF" "#1E1E1E"
  flutter_forge_color update cardBackground --light="#F0F0F0"
  flutter_forge_color update cardBackground --light="#F0F0F0" --dark="#222222"
  flutter_forge_color remove cardBackground
  flutter_forge_color list
''');
}
