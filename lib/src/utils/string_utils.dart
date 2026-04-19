abstract final class StringUtils {
  static String toPascalCase(String snake) => snake
      .split('_')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join();

  static String toCamelCase(String snake) {
    final pascal = toPascalCase(snake);
    if (pascal.isEmpty) return pascal;
    return '${pascal[0].toLowerCase()}${pascal.substring(1)}';
  }

  static String toSnakeCase(String input) => input
      .replaceAllMapped(
        RegExp('[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      )
      .replaceFirst(RegExp('^_'), '');

  /// Extracts the reverse-domain org from a bundle ID.
  /// e.g. "com.myco.myapp.dev" → "com.myco"
  static String extractOrg(String bundleId) {
    final parts = bundleId.split('.');
    return parts.take(parts.length - 1).join('.');
  }

  /// Extracts the base app name segment from a bundle ID.
  /// e.g. "com.myco.myapp.dev" → "myapp"  (the second-to-last segment)
  static String extractAppSegment(String bundleId) {
    final parts = bundleId.split('.');
    if (parts.length < 2) return parts.last;
    return parts[parts.length - 2];
  }

  static bool isSnakeCase(String s) =>
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(s);

  static bool isValidBundleId(String s) =>
      RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*){2,}$')
          .hasMatch(s);

  static bool isValidUrl(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  static bool isValidWsUrl(String s) {
    final uri = Uri.tryParse(s);
    return uri != null && (uri.scheme == 'wss' || uri.scheme == 'ws');
  }
}
