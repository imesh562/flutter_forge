import 'dart:convert';
import 'dart:io';

abstract final class ProcessUtils {
  /// Runs [executable] with [arguments], streaming output to the terminal.
  /// Throws [ProcessException] on non-zero exit code.
  static Future<void> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool verbose = true,
  }) async {
    // On Windows, batch-script executables (flutter.bat, dart.bat) are not
    // found by Process.start unless routed through the shell.
    final String resolvedExecutable;
    final List<String> resolvedArguments;
    if (Platform.isWindows) {
      resolvedExecutable = 'cmd';
      resolvedArguments = ['/c', executable, ...arguments];
    } else {
      resolvedExecutable = executable;
      resolvedArguments = arguments;
    }

    final process = await Process.start(
      resolvedExecutable,
      resolvedArguments,
      workingDirectory: workingDirectory,
    );

    // Always drain both streams to prevent pipe-buffer deadlock when the
    // process produces large output. Forward to the terminal only in verbose mode.
    final stderrBuf = StringBuffer();
    process.stdout.listen(verbose ? stdout.add : (_) {});
    process.stderr.listen((data) {
      if (verbose) stderr.add(data);
      stderrBuf.write(utf8.decode(data, allowMalformed: true));
    });

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      // When running silently, surface stderr in the exception so it isn't lost.
      final details = (!verbose && stderrBuf.isNotEmpty)
          ? '\n${stderrBuf.toString().trim()}'
          : '';
      throw ProcessException(
        executable,
        arguments,
        'Process exited with code $exitCode$details',
        exitCode,
      );
    }
  }

  /// Returns true when [executable] is found on PATH.
  /// Uses `where` on Windows and `which` on macOS/Linux.
  static Future<bool> isAvailable(String executable) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [executable],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
