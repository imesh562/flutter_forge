/// The current flutter_forge package version.
///
/// Keep in sync with the `version:` field in pubspec.yaml — duplicated here
/// (rather than parsed from pubspec.yaml at runtime) because a globally
/// activated executable has no reliable path back to its own source
/// pubspec.yaml. Every `--version` flag across the three executables reads
/// from this single constant so they can't drift from each other.
const String packageVersion = '1.0.0';
