import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:supdesk/supdesk.dart';

/// A queued response for [MockAdapter] to replay.
class MockResponse {
  const MockResponse({
    this.status = 200,
    this.json,
    this.text,
    this.headers = const {},
  });

  final int status;

  /// Encoded to JSON. Ignored when [text] is given.
  final Object? json;

  /// Raw response text, for testing malformed bodies.
  final String? text;

  final Map<String, String> headers;

  String get body {
    if (text != null) return text!;
    if (json == null) return '';
    return jsonEncode(json);
  }
}

/// One request the adapter saw.
class RecordedRequest {
  RecordedRequest(this.uri, this.method, this.headers, this.rawBody);

  final Uri uri;
  final String method;
  final Map<String, dynamic> headers;
  final String? rawBody;

  /// The decoded request body, or `null` when there was none.
  Object? get body => rawBody == null ? null : jsonDecode(rawBody!);

  /// The decoded request body as a JSON object.
  Map<String, dynamic> get json => body! as Map<String, dynamic>;

  /// Reads a request header, case-insensitively.
  String? header(String name) {
    final wanted = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == wanted) return entry.value.toString();
    }
    return null;
  }
}

/// A `fetch` double for dio.
///
/// The client takes a [Dio] as an option, so tests swap its adapter instead of
/// patching anything global. Running out of queued entries is a hard error
/// rather than a silent repeat, so a test that fires more requests than it
/// expects fails loudly.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(Iterable<Object> responses) : _queue = responses.toList();

  final List<Object> _queue;

  /// Every request the adapter saw, in order.
  final List<RecordedRequest> calls = [];

  /// How many queued responses are left.
  int get remaining => _queue.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(
      RecordedRequest(
        options.uri,
        options.method,
        options.headers,
        options.data as String?,
      ),
    );

    if (_queue.isEmpty) {
      throw StateError(
        'mock adapter: request #${calls.length} to ${options.uri} had no '
        'queued response.',
      );
    }

    final next = _queue.removeAt(0);
    if (next is Exception) throw next;

    final spec = next as MockResponse;
    return ResponseBody.fromString(
      spec.body,
      spec.status,
      headers: {
        'content-type': const ['application/json'],
        for (final entry in spec.headers.entries) entry.key: [entry.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// An adapter whose requests never settle, for timeout tests.
class HangingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      Completer<ResponseBody>().future;

  @override
  void close({bool force = false}) {}
}

/// Builds a [Dio] wired to [adapter] the way the SDK configures its own.
Dio dioWith(HttpClientAdapter adapter) => Dio(
      BaseOptions(
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    )..httpClientAdapter = adapter;

/// Builds a transport pointed at a stub base URL, with time under test control.
SupDeskHttpClient httpClientWith(
  HttpClientAdapter adapter, {
  String apiKey = 'sd_test_key',
  String baseUrl = 'https://api.example.test/v1',
  Duration timeout = const Duration(seconds: 30),
  int maxRetries = defaultMaxRetries,
  bool retryUnsafeMethods = false,
  Map<String, String> defaultHeaders = const {},
  List<Duration>? sleeps,
}) =>
    SupDeskHttpClient(
      apiKey: apiKey,
      baseUrl: baseUrl,
      dio: dioWith(adapter),
      timeout: timeout,
      maxRetries: maxRetries,
      retryUnsafeMethods: retryUnsafeMethods,
      defaultHeaders: defaultHeaders,
      sleep: (duration) async => sleeps?.add(duration),
      random: () => 1,
    );

/// Builds a [SupDesk] client backed by [adapter].
SupDesk clientWith(HttpClientAdapter adapter) => SupDesk(
      apiKey: 'sd_test_key',
      baseUrl: 'https://api.example.test/v1',
      dio: dioWith(adapter),
      isClientSideRuntime: () => false,
    );

/// Builds a `{ data, pagination }` list envelope.
Map<String, Object?> pageOf(
  List<Object?> data, {
  int limit = 20,
  int offset = 0,
  bool hasMore = false,
}) =>
    {
      'data': data,
      'pagination': {'limit': limit, 'offset': offset, 'has_more': hasMore},
    };

/// Builds a SupDesk error envelope.
Map<String, Object?> errorBody(String code, [String? message]) => {
      'error': {'code': code, 'message': message ?? '$code occurred'},
    };
