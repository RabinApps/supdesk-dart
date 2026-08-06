import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../version.dart';
import 'errors.dart';
import 'query.dart';
import 'retry.dart';

/// The SupDesk API root.
const String defaultBaseUrl = 'https://api.supdesk.app/v1';

/// Per-request deadline applied when the caller sets none.
const Duration defaultTimeout = Duration(seconds: 30);

/// SupDesk documents a 1 MB maximum request size.
const int maxRequestBytes = 1048576;

/// The only class in the library that talks to `package:dio`.
///
/// Everything above it deals in decoded JSON and typed exceptions, and the
/// retry policy lives here rather than in a dio interceptor so it can be tested
/// with an injected clock.
class SupDeskHttpClient {
  /// Creates a transport bound to one API key.
  ///
  /// Pass [dio] to supply a pre-configured client (interceptors, proxy, custom
  /// adapter); the caller keeps ownership of it and [close] leaves it alone.
  SupDeskHttpClient({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    Dio? dio,
    this.timeout = defaultTimeout,
    this.maxRetries = defaultMaxRetries,
    this.retryUnsafeMethods = false,
    Map<String, String> defaultHeaders = const {},
    Future<void> Function(Duration)? sleep,
    double Function()? random,
  })  : defaultHeaders = _lowercaseKeys(defaultHeaders),
        _ownsDio = dio == null,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: timeout > Duration.zero ? timeout : null,
                responseType: ResponseType.plain,
                validateStatus: (_) => true,
              ),
            ),
        _sleep = sleep ?? sleepFor,
        _random = random ?? math.Random().nextDouble;

  /// Project-scoped API key sent as a bearer token.
  final String apiKey;

  /// API root every path is joined onto.
  final String baseUrl;

  /// Per-request deadline. [Duration.zero] disables it.
  final Duration timeout;

  /// Retries attempted after the first request.
  final int maxRetries;

  /// Whether `POST` may be replayed on connection errors and 5xx responses.
  final bool retryUnsafeMethods;

  /// Headers applied to every request. `authorization` cannot be overridden.
  final Map<String, String> defaultHeaders;

  final Dio _dio;
  final bool _ownsDio;
  final Future<void> Function(Duration) _sleep;
  final double Function() _random;

  /// The underlying dio instance, for callers who need to reach past the SDK.
  Dio get dio => _dio;

  /// Issues a request, retrying per the policy in `retry.dart`, and returns the
  /// decoded JSON body (`null` for `204 No Content`).
  Future<Object?> request({
    required String method,
    required String path,
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    CancelToken? cancelToken,
  }) async {
    final url = joinUrl(baseUrl, path) + buildQueryString(query);
    final payload = body == null ? null : _encodeBody(body);
    final requestHeaders = _buildHeaders(headers, hasBody: payload != null);

    var attempt = 0;

    for (;;) {
      try {
        return await _attempt(
          url: url,
          method: method,
          headers: requestHeaders,
          payload: payload,
          timeout: timeout ?? this.timeout,
          cancelToken: cancelToken,
        );
      } on SupDeskException catch (error) {
        final retryable = shouldRetry(
          error: error,
          method: method,
          attempt: attempt,
          maxRetries: maxRetries,
          retryUnsafeMethods: retryUnsafeMethods,
        );

        if (!retryable) rethrow;

        final retryAfter = error is SupDeskApiException
            ? parseRetryAfter(error.header('retry-after'))
            : null;

        await _sleep(
          backoffDelay(
            attempt: attempt,
            retryAfter: retryAfter,
            random: _random,
          ),
        );
        attempt += 1;
      }
    }
  }

  /// Releases the underlying dio instance, unless one was injected.
  void close() {
    if (_ownsDio) _dio.close();
  }

  Future<Object?> _attempt({
    required String url,
    required String method,
    required Map<String, String> headers,
    required String? payload,
    required Duration timeout,
    required CancelToken? cancelToken,
  }) async {
    Response<String> response;

    try {
      var pending = _dio.request<String>(
        url,
        data: payload,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
          // dio only honours sendTimeout when there is a body to send.
          sendTimeout:
              payload != null && timeout > Duration.zero ? timeout : null,
          receiveTimeout: timeout > Duration.zero ? timeout : null,
        ),
      );

      if (timeout > Duration.zero) {
        // The authoritative deadline. dio's own receive timeout does not fire
        // against a stubbed adapter, and a caller who asked for 5s should get
        // an answer in 5s whatever the transport is doing.
        pending = pending.timeout(
          timeout,
          onTimeout: () => throw SupDeskTimeoutException(timeout),
        );
      }

      response = await pending;
    } on DioException catch (error) {
      // Caller cancellation is theirs to observe — pass it through untouched.
      if (error.type == DioExceptionType.cancel) rethrow;
      throw _mapDioException(error, url, timeout);
    }

    return parseResponse(
      statusCode: response.statusCode ?? 0,
      body: response.data,
      headers: response.headers.map,
    );
  }

  SupDeskException _mapDioException(
    DioException error,
    String url,
    Duration timeout,
  ) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return SupDeskTimeoutException(timeout, cause: error);
      case DioExceptionType.badResponse:
        // Only reachable behind an injected Dio whose `validateStatus` rejects
        // statuses before this client sees them.
        final response = error.response;
        if (response != null) {
          try {
            parseResponse(
              statusCode: response.statusCode ?? 0,
              body: response.data?.toString(),
              headers: response.headers.map,
            );
          } on SupDeskException catch (mapped) {
            return mapped;
          }
        }
        return SupDeskConnectionException(
          'Request to $url failed: ${error.message}',
          error,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return SupDeskConnectionException(
          'Request to $url failed: ${error.message ?? error.error ?? error.type.name}',
          error,
        );
    }
  }

  Map<String, String> _buildHeaders(
    Map<String, String>? perCall, {
    required bool hasBody,
  }) {
    final headers = <String, String>{
      'accept': 'application/json',
      'user-agent': 'supdesk-dart/$packageVersion',
      ...defaultHeaders,
      ..._lowercaseKeys(perCall ?? const {}),
    };

    if (hasBody) headers['content-type'] = 'application/json';

    // Last, so neither default nor per-call headers can replace it.
    headers['authorization'] = 'Bearer $apiKey';

    return headers;
  }

  String _encodeBody(Object body) {
    final encoded = jsonEncode(body);
    final size = utf8.encode(encoded).length;

    if (size > maxRequestBytes) {
      throw RequestTooLargeException(size, maxRequestBytes);
    }

    return encoded;
  }
}

Map<String, String> _lowercaseKeys(Map<String, String> headers) => {
      for (final entry in headers.entries) entry.key.toLowerCase(): entry.value,
    };

/// Turns a response into a decoded body or a typed exception.
///
/// A non-JSON body must never surface as a [FormatException]: an HTML error
/// page from a proxy should arrive as a [SupDeskApiException] carrying the raw
/// text, not as a parse failure that hides the actual status.
Object? parseResponse({
  required int statusCode,
  required String? body,
  Map<String, List<String>> headers = const {},
}) {
  final text = statusCode == 204 ? '' : (body ?? '');

  Object? parsed;
  var parseFailed = false;
  if (text.isNotEmpty) {
    try {
      parsed = jsonDecode(text);
    } on FormatException {
      parseFailed = true;
    }
  }

  if (statusCode >= 200 && statusCode < 300) {
    if (parseFailed) {
      throw createApiException(
        statusCode: statusCode,
        code: SupDeskErrorCode.internalError,
        message: 'Expected a JSON response body but could not parse one.',
        headers: headers,
        body: text,
      );
    }
    return parsed;
  }

  final envelope = _extractErrorEnvelope(parsed);
  final message = envelope?.message;

  throw createApiException(
    statusCode: statusCode,
    code: envelope?.code ?? '',
    // An envelope present but with an empty message should still fall back to
    // something a human can act on.
    message: (message == null || message.isEmpty)
        ? 'SupDesk API request failed with status $statusCode.'
        : message,
    headers: headers,
    body: parseFailed ? text : (parsed ?? text),
  );
}

({String code, String message})? _extractErrorEnvelope(Object? body) {
  if (body is! Map<String, dynamic>) return null;

  final error = body['error'];
  if (error is! Map<String, dynamic>) return null;

  final code = error['code'];
  final message = error['message'];

  return (
    code: code is String ? code : '',
    message: message is String ? message : '',
  );
}
