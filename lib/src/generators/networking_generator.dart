import 'package:flutter_forge/src/models/project_config.dart';
import 'package:flutter_forge/src/utils/file_utils.dart';
import 'package:path/path.dart' as p;

final class NetworkingGenerator {
  Future<void> run(ProjectConfig config) async {
    final pkg = config.projectName;
    final base = p.join(config.projectPath, 'lib', 'core', 'network');

    await Future.wait([
      _writeNetworkConfig(base, pkg),
      _writeApiHelper(base, pkg),
      _writeMockApiHelper(base, pkg),
      _writeWebhookHelper(base, pkg),
    ]);
  }

  Future<void> _writeNetworkConfig(String base, String pkg) async {
    await FileUtils.writeFile(
      p.join(base, 'network_config.dart'),
      '''
abstract final class NetworkConfig {
  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 30);
}
''',
    );
  }

  Future<void> _writeApiHelper(String base, String pkg) async {
    await FileUtils.writeFile(
      p.join(base, 'api_helper.dart'),
      '''
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart' hide Environment;

import 'package:$pkg/core/di/injection.dart';
import 'package:$pkg/error/exceptions.dart';
import 'package:$pkg/flavors/flavor_config.dart';
import 'network_config.dart';

@LazySingleton(env: [Environment.stg, Environment.preProd, Environment.prod])
class ApiHelper {
  ApiHelper() {
    _dio = Dio(
      BaseOptions(
        baseUrl: FlavorConfig.instance.baseUrl,
        connectTimeout: NetworkConfig.connectTimeout,
        receiveTimeout: NetworkConfig.receiveTimeout,
        sendTimeout: NetworkConfig.sendTimeout,
      ),
    );
    _dio.interceptors.addAll([
      _authInterceptor(),
      LogInterceptor(requestBody: true, responseBody: true),
      _errorInterceptor(),
    ]);
  }

  late final Dio _dio;
  static const _storage = FlutterSecureStorage();

  /// Injects the stored auth token into every outgoing request.
  /// Token is read from the device secure keychain / keystore.
  Interceptor _authInterceptor() => InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer \$token';
          }
          handler.next(options);
        },
      );

  /// Converts Dio errors into typed [AppException]s before propagating.
  Interceptor _errorInterceptor() => InterceptorsWrapper(
        onError: (error, handler) {
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: mapHttpError(error),
              type: error.type,
              response: error.response,
            ),
          );
        },
      );

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, options: options);

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) =>
      _dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) =>
      _dio.delete<T>(path, options: options);
}
''',
    );
  }

  Future<void> _writeMockApiHelper(String base, String pkg) async {
    await FileUtils.writeFile(
      p.join(base, 'mock_api_helper.dart'),
      '''
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'api_helper.dart';

/// Active only in the DEV environment; returns empty 200 responses without
/// touching the network. Register real data by overriding specific methods
/// in feature-level tests.
@LazySingleton(as: ApiHelper, env: [Environment.dev])
final class MockApiHelper extends ApiHelper {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      _empty(path);

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) async =>
      _empty(path);

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) async =>
      _empty(path);

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) async =>
      _empty(path);

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) async =>
      _empty(path);

  Response<T> _empty<T>(String path) => Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
      );
}
''',
    );
  }

  Future<void> _writeWebhookHelper(String base, String pkg) async {
    await FileUtils.writeFile(
      p.join(base, 'webhook_helper.dart'),
      '''
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:injectable/injectable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:$pkg/flavors/flavor_config.dart';

/// Manages a single, persistent WebSocket connection with automatic
/// reconnection and exponential back-off.
///
/// Back-off schedule (capped at 64 s):
///   attempt 1 →  1 s
///   attempt 2 →  2 s
///   attempt 3 →  4 s
///   attempt 4 →  8 s
///   attempt 5 → 16 s
///   attempt 6 → 32 s
///   attempt 7+ → 64 s
///
/// All decoded JSON messages are forwarded to [stream].  Datasources filter
/// [stream] by `data['type']` to receive only the events they care about.
@lazySingleton
final class WebhookHelper {
  WebhookHelper() {
    _connect();
  }

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;
  int _attempt = 0;

  static const _maxBackoffSeconds = 64;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void _connect() {
    if (_disposed) return;
    _subscription?.cancel();
    _channel?.sink.close();

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(FlavorConfig.instance.wsUrl),
      );
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    _subscription = _channel!.stream.listen(
      (data) {
        if (data is String) {
          try {
            final decoded = jsonDecode(data) as Map<String, dynamic>;
            _controller.add(decoded);
            _attempt = 0; // reset back-off on successful message
          } catch (_) {
            // Ignore malformed JSON frames.
          }
        }
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: false,
    );
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _attempt++;
    final delay = Duration(
      seconds: min(_maxBackoffSeconds, pow(2, _attempt - 1).toInt()),
    );
    Future<void>.delayed(delay, _connect);
  }

  /// Sends a raw JSON payload through the open channel.
  /// No-op if the connection is not yet established.
  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
''',
    );
  }
}
