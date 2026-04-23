import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

final class ExceptionGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    await _writeExceptions(config, pkg);
    await _writeFailures(config, pkg);
  }

  Future<void> _writeExceptions(ProjectConfig config, String pkg) async {
    await FileUtils.writeFile(
      p.join(config.projectPath, 'lib', 'error', 'exceptions.dart'),
      r'''
import 'package:dio/dio.dart' as dio;

abstract class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Returned for 4xx/5xx server responses not covered by more specific types.
final class ServerException extends AppException {
  const ServerException(super.message);
}

/// Returned for 401, 403, and 407 responses.
final class UnAuthorizedException extends AppException {
  const UnAuthorizedException(super.message);
}

/// Returned for 426 — the client must update before proceeding.
final class ForceUpdateException extends AppException {
  const ForceUpdateException(super.message);
}

/// Returned for 503 — the service is temporarily unavailable.
final class MaintenanceException extends AppException {
  const MaintenanceException(super.message);
}

/// Returned for network-level failures (no HTTP status code available).
final class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Maps a [dio.DioException] to the appropriate typed [AppException].
/// Prefers the [message] field from the response body when present so that
/// business-level error messages (e.g. "Invalid password.") are preserved
/// regardless of HTTP status code.
AppException mapHttpError(dio.DioException error) {
  final statusCode = error.response?.statusCode;
  final body = error.response?.data;
  final serverMessage = body is Map ? body['message'] as String? : null;
  return switch (statusCode) {
    401 || 403 || 407 => UnAuthorizedException(serverMessage ?? 'Unauthorized'),
    426 => ForceUpdateException(serverMessage ?? 'App update required'),
    503 => MaintenanceException(serverMessage ?? 'Service under maintenance'),
    _ when statusCode != null =>
      ServerException(serverMessage ?? 'Server error: $statusCode'),
    _ => NetworkException(error.message ?? 'Network error'),
  };
}
''',
    );
  }

  Future<void> _writeFailures(ProjectConfig config, String pkg) async {
    await FileUtils.writeFile(
      p.join(config.projectPath, 'lib', 'error', 'failures.dart'),
      '''
import 'package:equatable/equatable.dart';

/// Domain-layer failure — returned from repositories via [Either].
abstract class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class UnAuthorizedFailure extends Failure {
  const UnAuthorizedFailure(super.message);
}

final class ForceUpdateFailure extends Failure {
  const ForceUpdateFailure(super.message);
}

final class MaintenanceFailure extends Failure {
  const MaintenanceFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
''',
    );
  }
}
