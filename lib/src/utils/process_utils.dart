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
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );

    if (verbose) {
      process.stdout.listen(stdout.add);
      process.stderr.listen(stderr.add);
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        'Process exited with code $exitCode',
        exitCode,
      );
    }
  }
}
