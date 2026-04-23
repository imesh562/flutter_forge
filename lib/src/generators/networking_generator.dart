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
      _writeMockConfig(base),
      _writeMockResponses(base),
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

  /// Throws [ServerException] when the response body contains
  /// `{"success": false, ...}` regardless of the HTTP status code.
  void _checkSuccess<T>(Response<T> response) {
    final data = response.data;
    if (data is Map && data['success'] == false) {
      throw ServerException(
        data['message'] as String? ?? 'Request failed',
      );
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      _checkSuccess(response);
      return response;
    } on DioException catch (e) {
      throw mapHttpError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(path, data: data, options: options);
      _checkSuccess(response);
      return response;
    } on DioException catch (e) {
      throw mapHttpError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(path, data: data, options: options);
      _checkSuccess(response);
      return response;
    } on DioException catch (e) {
      throw mapHttpError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch<T>(path, data: data, options: options);
      _checkSuccess(response);
      return response;
    } on DioException catch (e) {
      throw mapHttpError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(path, options: options);
      _checkSuccess(response);
      return response;
    } on DioException catch (e) {
      throw mapHttpError(e);
    }
  }
}
''',
    );
  }

  Future<void> _writeMockConfig(String base) async {
    await FileUtils.writeFile(
      p.join(base, 'mock_config.dart'),
      '''
// Toggle kUseMockApi to enable or disable mock networking in the DEV flavor.
// When false, real network calls are made even in DEV.
// Use the flutter_forge CLI menu to toggle this value.
bool kUseMockApi = false;
''',
    );
  }

  Future<void> _writeMockResponses(String base) async {
    await FileUtils.writeFile(
      p.join(base, 'mock_responses.dart'),
      '''
// Managed by flutter_forge CLI — use the Mock API menu to add or remove entries.
// Key format: 'METHOD /path'  e.g. 'POST /auth/login', 'GET /user/profile'
// Values are plain Dart maps — no serialisation needed.
const Map<String, dynamic> kMockResponses = {
// <<MOCK_ENTRIES>>
};
''',
    );
  }

  Future<void> _writeMockApiHelper(String base, String pkg) async {
    await FileUtils.writeFile(
      p.join(base, 'mock_api_helper.dart'),
      '''
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:$pkg/error/exceptions.dart';
import 'api_helper.dart';
import 'mock_config.dart';
import 'mock_responses.dart';

/// Active only in the DEV environment.
/// When [kUseMockApi] is true, intercepts every call and returns the matching
/// entry from [kMockResponses], or an empty 200 if no entry is registered.
/// When [kUseMockApi] is false, delegates to the real [ApiHelper] so you can
/// hit a live DEV server without changing flavors.
@LazySingleton(as: ApiHelper, env: [Environment.dev])
final class MockApiHelper extends ApiHelper {
  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    if (!kUseMockApi) return super.get(path, queryParameters: queryParameters, options: options);
    return _mock('GET', path);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    if (!kUseMockApi) return super.post(path, data: data, options: options);
    return _mock('POST', path);
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    if (!kUseMockApi) return super.put(path, data: data, options: options);
    return _mock('PUT', path);
  }

  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) async {
    if (!kUseMockApi) return super.patch(path, data: data, options: options);
    return _mock('PATCH', path);
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) async {
    if (!kUseMockApi) return super.delete(path, options: options);
    return _mock('DELETE', path);
  }

  Response<T> _mock<T>(String method, String path) {
    final data = kMockResponses['\$method \$path'];
    if (data is Map && data['success'] == false) {
      throw ServerException(data['message'] as String? ?? 'Request failed');
    }
    return Response<T>(
      data: data as T?,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
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
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _attempt = 0;

  static const _maxBackoffSeconds = 64;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  Future<void> _connect() async {
    if (_disposed) return;
    _subscription?.cancel();
    _channel?.sink.close();

    _channel = WebSocketChannel.connect(
      Uri.parse(FlavorConfig.instance.wsUrl),
    );

    // In web_socket_channel v2+, connection errors surface via the ready
    // future, not the stream. Awaiting it here ensures failures are caught
    // and routed to the reconnect logic instead of crashing as unhandled
    // exceptions.
    try {
      await _channel!.ready;
    } catch (_) {
      _scheduleReconnect();
      return;
    }

    // Guard: dispose() may have been called while we awaited the handshake.
    if (_disposed) return;

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
    // Cancel any pending reconnect before scheduling a new one so that rapid
    // onError + onDone firings don't stack up multiple concurrent _connect calls.
    _reconnectTimer?.cancel();
    _attempt++;
    final delay = Duration(
      seconds: min(_maxBackoffSeconds, pow(2, _attempt - 1).toInt()),
    );
    // _connect is async; Timer discards the returned Future. Errors are
    // handled internally so there are no unhandled rejections.
    _reconnectTimer = Timer(delay, () => _connect());
  }

  /// Sends a raw JSON payload through the open channel.
  /// No-op if the connection is not yet established.
  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
''',
    );
  }
}
